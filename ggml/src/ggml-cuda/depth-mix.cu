#include "depth-mix.cuh"

#define DEPTH_MIX_THREADS 256

template <int n_query>
static __global__ void depth_mix_f32(
        const float * __restrict__ stack, const float * __restrict__ x, const float * __restrict__ query, float * __restrict__ dst,
        const int n_embd, const int n_stack,
        const int64_t s_nb1, const int64_t s_nb2, const int64_t x_nb1, const int64_t q_nb1, const int64_t d_nb1, const int64_t d_nb2,
        const float eps, const float scale) {
    constexpr int n_dots  = DEPTH_MIX_MAX_STATES*n_query;
    constexpr int n_warps = DEPTH_MIX_THREADS/WARP_SIZE;

    const int t = blockIdx.x;
    const float * xt = x + t*x_nb1;
    const float * st = stack + t*s_nb2;

    float dots[n_dots] = {};
    float sumsq = 0.0f;

    for (int i = threadIdx.x; i < n_embd; i += DEPTH_MIX_THREADS) {
        float qv[n_query];
#pragma unroll
        for (int q = 0; q < n_query; ++q) {
            qv[q] = query[q*q_nb1 + i];
        }
        const float xi = xt[i];
        sumsq += xi*xi;
#pragma unroll
        for (int j = 0; j < DEPTH_MIX_MAX_STATES; ++j) {
            if (j > n_stack) {
                break;
            }
            const float s = j < n_stack ? st[j*s_nb1 + i] : xi;
#pragma unroll
            for (int q = 0; q < n_query; ++q) {
                dots[j*n_query + q] += s*qv[q];
            }
        }
    }

    __shared__ float partial[n_warps][n_dots + 1];
    __shared__ float weights[n_dots];
    __shared__ float rms;

    const int warp = threadIdx.x / WARP_SIZE;
    const int lane = threadIdx.x % WARP_SIZE;

#pragma unroll
    for (int k = 0; k < n_dots; ++k) {
        if (k >= (n_stack + 1)*n_query) {
            break;
        }
        const float v = warp_reduce_sum(dots[k]);
        if (lane == 0) {
            partial[warp][k] = v;
        }
    }
    sumsq = warp_reduce_sum(sumsq);
    if (lane == 0) {
        partial[warp][n_dots] = sumsq;
    }
    __syncthreads();

    if (threadIdx.x < n_query) {
        const int q = threadIdx.x;

        float ss = 0.0f;
        for (int w = 0; w < n_warps; ++w) {
            ss += partial[w][n_dots];
        }
        const float r = rsqrtf(ss/n_embd + eps);

        float logits[DEPTH_MIX_MAX_STATES];
        float max = -INFINITY;
        for (int j = 0; j <= n_stack; ++j) {
            float d = 0.0f;
            for (int w = 0; w < n_warps; ++w) {
                d += partial[w][j*n_query + q];
            }
            logits[j] = scale*(j == n_stack ? d*r : d);
            max = fmaxf(max, logits[j]);
        }
        float total = 0.0f;
        for (int j = 0; j <= n_stack; ++j) {
            logits[j] = expf(logits[j] - max);
            total += logits[j];
        }
        for (int j = 0; j <= n_stack; ++j) {
            weights[j*n_query + q] = logits[j]/total;
        }
        if (q == 0) {
            rms = r;
        }
    }
    __syncthreads();

    for (int i = threadIdx.x; i < n_embd; i += DEPTH_MIX_THREADS) {
        const float xi = xt[i]*rms;
        float out[n_query];
#pragma unroll
        for (int q = 0; q < n_query; ++q) {
            out[q] = weights[n_stack*n_query + q]*xi;
        }
        for (int j = 0; j < n_stack; ++j) {
            const float s = st[j*s_nb1 + i];
#pragma unroll
            for (int q = 0; q < n_query; ++q) {
                out[q] += weights[j*n_query + q]*s;
            }
        }
#pragma unroll
        for (int q = 0; q < n_query; ++q) {
            dst[t*d_nb2 + q*d_nb1 + i] = out[q];
        }
    }
}

void ggml_cuda_op_depth_mix(ggml_backend_cuda_context & ctx, ggml_tensor * dst) {
    const ggml_tensor * x     = dst->src[0];
    const ggml_tensor * query = dst->src[1];
    const ggml_tensor * stack = dst->src[2];

    const float eps   = ggml_get_op_params_f32(dst, 0);
    const float scale = ggml_get_op_params_f32(dst, 1);

    const int n_embd   = x->ne[0];
    const int n_tokens = x->ne[1];
    const int n_query  = query->ne[1];
    const int n_stack  = stack ? stack->ne[1] : 0;

    GGML_ASSERT(n_stack + 1 <= DEPTH_MIX_MAX_STATES && n_query <= DEPTH_MIX_MAX_QUERIES);

    const float * stack_d = stack ? (const float *) stack->data : nullptr;
    const int64_t s_nb1   = stack ? stack->nb[1]/sizeof(float) : 0;
    const int64_t s_nb2   = stack ? stack->nb[2]/sizeof(float) : 0;

    const dim3 blocks(n_tokens, 1, 1);
    cudaStream_t stream = ctx.stream();

    auto launch = [&](auto nq) {
        constexpr int kq = decltype(nq)::value;
        depth_mix_f32<kq><<<blocks, DEPTH_MIX_THREADS, 0, stream>>>(
            stack_d, (const float *) x->data, (const float *) query->data, (float *) dst->data, n_embd, n_stack,
            s_nb1, s_nb2, x->nb[1]/sizeof(float), query->nb[1]/sizeof(float), dst->nb[1]/sizeof(float), dst->nb[2]/sizeof(float),
            eps, scale);
    };

    switch (n_query) {
        case 1: launch(std::integral_constant<int, 1>{}); break;
        case 2: launch(std::integral_constant<int, 2>{}); break;
        case 3: launch(std::integral_constant<int, 3>{}); break;
        case 4: launch(std::integral_constant<int, 4>{}); break;
        default: GGML_ABORT("fatal error");
    }
}

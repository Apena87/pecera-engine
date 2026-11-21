#include "tanh-gate-mix.cuh"

static __global__ void tanh_gate_mix_f32(
        const float * __restrict__ x, const float * __restrict__ y, const float * __restrict__ gates, float * __restrict__ dst,
        const int n, const int ne1, const int ne2,
        const int64_t x_nb1, const int64_t x_nb2, const int64_t x_nb3,
        const int64_t y_nb1, const int64_t y_nb2, const int64_t y_nb3,
        const int64_t g_nb1, const int64_t g_nb2, const int64_t g_nb3,
        const int64_t d_nb1, const int64_t d_nb2, const int64_t d_nb3) {
    const int i = blockIdx.x*blockDim.x + threadIdx.x;
    if (i >= n) {
        return;
    }

    const int64_t r  = blockIdx.y;
    const int64_t i1 = r % ne1;
    const int64_t i2 = (r / ne1) % ne2;
    const int64_t i3 = r / (ne1*ne2);

    const float * g = gates + i1*g_nb1 + i2*g_nb2 + i3*g_nb3;

    dst[i1*d_nb1 + i2*d_nb2 + i3*d_nb3 + i] =
        x[i1*x_nb1 + i2*x_nb2 + i3*x_nb3 + i]*(1.0f - tanhf(g[n + i])) + y[i1*y_nb1 + i2*y_nb2 + i3*y_nb3 + i]*tanhf(g[i]);
}

void ggml_cuda_op_tanh_gate_mix(ggml_backend_cuda_context & ctx, ggml_tensor * dst) {
    const ggml_tensor * x     = dst->src[0];
    const ggml_tensor * y     = dst->src[1];
    const ggml_tensor * gates = dst->src[2];

    const int n = x->ne[0];
    const int64_t nrows = ggml_nrows(x);
    GGML_ASSERT(nrows <= 65535);

    constexpr int threads = 256;
    const dim3 blocks((n + threads - 1)/threads, nrows, 1);

    const size_t f = sizeof(float);
    tanh_gate_mix_f32<<<blocks, threads, 0, ctx.stream()>>>(
        (const float *) x->data, (const float *) y->data, (const float *) gates->data, (float *) dst->data,
        n, x->ne[1], x->ne[2],
        x->nb[1]/f, x->nb[2]/f, x->nb[3]/f,
        y->nb[1]/f, y->nb[2]/f, y->nb[3]/f,
        gates->nb[1]/f, gates->nb[2]/f, gates->nb[3]/f,
        dst->nb[1]/f, dst->nb[2]/f, dst->nb[3]/f);
}

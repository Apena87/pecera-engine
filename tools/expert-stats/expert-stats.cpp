// Counts which routed experts each MoE layer selects over a text file, to judge whether a small hot set of experts
// could serve most lookups (pecera roadmap item 8).
//
// usage: llama-expert-stats -m model.gguf -f corpus.txt [-c 8192] [-ngl 99] [-ot ...] [--chunk 4096] > stats.csv
// Output (stdout): one CSV row per layer and expert: layer,expert,count. Summary lines go to stderr.

#include "arg.h"
#include "common.h"
#include "log.h"
#include "llama.h"
#include "ggml.h"
#include "ggml-backend.h"

#include <algorithm>
#include <clocale>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <map>
#include <string>
#include <vector>

struct stats_data {
    std::map<int, std::vector<uint64_t>> counts; // graph layer index -> per expert count
    std::vector<uint8_t>                 buf;
    uint64_t                             tensors_seen = 0;
};

static int layer_of(const char * name) {
    static const char * prefix = "ffn_moe_topk-";
    const size_t n = strlen(prefix);
    if (strncmp(name, prefix, n) != 0) {
        return -1;
    }
    return atoi(name + n);
}

static bool cb_eval(struct ggml_tensor * t, bool ask, void * user_data) {
    const int il = layer_of(t->name);
    if (ask) {
        return il >= 0;
    }
    if (il < 0 || t->type != GGML_TYPE_I32) {
        return true;
    }
    auto * sd = (stats_data *) user_data;
    const size_t nbytes = ggml_nbytes(t);
    sd->buf.resize(nbytes);
    ggml_backend_tensor_get(t, sd->buf.data(), 0, nbytes);

    // ne[0] = experts used per token, ne[1] = tokens; walk with strides in case the tensor is a view
    const int64_t n_used = t->ne[0];
    const int64_t n_tok  = t->ne[1];
    auto & c = sd->counts[il];
    for (int64_t j = 0; j < n_tok; ++j) {
        for (int64_t i = 0; i < n_used; ++i) {
            const size_t off = (size_t) (i * t->nb[0] + j * t->nb[1]);
            if (off + sizeof(int32_t) > nbytes) {
                continue;
            }
            int32_t e;
            memcpy(&e, sd->buf.data() + off, sizeof(e));
            if (e < 0) {
                continue;
            }
            if ((size_t) e >= c.size()) {
                c.resize(e + 1, 0);
            }
            c[e]++;
        }
    }
    sd->tensors_seen++;
    return true;
}

int main(int argc, char ** argv) {
    std::setlocale(LC_NUMERIC, "C");

    stats_data sd;
    common_params params;
    common_init();

    int chunk = 4096;
    std::vector<char *> args;
    for (int i = 0; i < argc; ++i) {
        if (strcmp(argv[i], "--chunk") == 0 && i + 1 < argc) {
            chunk = atoi(argv[++i]);
            continue;
        }
        args.push_back(argv[i]);
    }
    if (!common_params_parse((int) args.size(), args.data(), params, LLAMA_EXAMPLE_COMMON)) {
        return 1;
    }

    llama_backend_init();
    llama_numa_init(params.numa);

    params.cb_eval           = cb_eval;
    params.cb_eval_user_data = &sd;
    params.warmup            = false;

    auto llama_init = common_init_from_params(params);
    auto * model = llama_init->model();
    auto * ctx   = llama_init->context();
    if (model == nullptr || ctx == nullptr) {
        LOG_ERR("failed to init\n");
        return 1;
    }

    std::vector<llama_token> tokens = common_tokenize(ctx, params.prompt, false, true);
    LOG_INF("corpus tokens: %zu, chunk %d, batch %d\n", tokens.size(), chunk, params.n_batch);

    const size_t n_batch = (size_t) std::max(1, params.n_batch);
    for (size_t start = 0; start < tokens.size(); start += chunk) {
        llama_memory_clear(llama_get_memory(ctx), true);
        const size_t end = std::min(tokens.size(), start + (size_t) chunk);
        for (size_t b = start; b < end; b += n_batch) {
            std::vector<llama_token> sub(tokens.begin() + b, tokens.begin() + std::min(end, b + n_batch));
            auto batch = common_batch_get_one(ctx, sub);
            if (llama_process(ctx, LLAMA_PROCESS_TYPE_DECODE, batch.get())) {
                LOG_ERR("decode failed at token %zu\n", b);
                return 1;
            }
        }
        fprintf(stderr, "processed %zu / %zu tokens\n", end, tokens.size());
    }

    printf("layer,expert,count\n");
    for (auto & [il, c] : sd.counts) {
        for (size_t e = 0; e < c.size(); ++e) {
            printf("%d,%zu,%llu\n", il, e, (unsigned long long) c[e]);
        }
        std::vector<uint64_t> s = c;
        std::sort(s.begin(), s.end(), std::greater<uint64_t>());
        uint64_t total = 0;
        for (auto v : s) total += v;
        auto cover = [&](size_t k) {
            uint64_t a = 0;
            for (size_t i = 0; i < std::min(k, s.size()); ++i) a += s[i];
            return total ? 100.0 * (double) a / (double) total : 0.0;
        };
        const size_t used = (size_t) std::count_if(s.begin(), s.end(), [](uint64_t v) { return v > 0; });
        fprintf(stderr, "layer %2d: selections %llu, experts used %zu, top16 %.1f%%, top32 %.1f%%, top64 %.1f%%\n",
                il, (unsigned long long) total, used, cover(16), cover(32), cover(64));
    }
    fprintf(stderr, "topk tensors seen: %llu\n", (unsigned long long) sd.tensors_seen);

    llama_backend_free();
    return 0;
}

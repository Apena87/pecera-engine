#include "common.cuh"

#define DEPTH_MIX_MAX_STATES 16
#define DEPTH_MIX_MAX_QUERIES 4

void ggml_cuda_op_depth_mix(ggml_backend_cuda_context & ctx, ggml_tensor * dst);

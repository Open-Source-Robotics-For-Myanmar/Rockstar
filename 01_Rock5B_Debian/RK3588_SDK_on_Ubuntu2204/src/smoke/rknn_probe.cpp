#include <cstdio>
#include "rknn_api.h"
int main(int argc, char** argv) {
    if (argc != 2) {
        std::puts("RKNN runtime loaded. Pass an RK3588 .rknn model to test initialization.");
        return argc == 1 ? 0 : 2;
    }
    rknn_context ctx = 0;
    // size=0 tells RKNN to interpret model as a file path.
    int rc = rknn_init(&ctx, argv[1], 0, 0, nullptr);
    if (rc != RKNN_SUCC) {
        std::fprintf(stderr, "rknn_init failed: %d\n", rc);
        return 1;
    }
    rknn_sdk_version versions{};
    rc = rknn_query(ctx, RKNN_QUERY_SDK_VERSION, &versions, sizeof(versions));
    if (rc == RKNN_SUCC) {
        std::printf("Runtime: %s\nDriver: %s\n", versions.api_version, versions.drv_version);
        std::puts("PASS: model initialization and version query; inference not tested.");
    } else {
        std::fprintf(stderr, "rknn_query failed: %d\n", rc);
    }
    const int cleanup = rknn_destroy(ctx);
    return rc == RKNN_SUCC && cleanup == RKNN_SUCC ? 0 : 1;
}

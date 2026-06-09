#include <stdio.h>
#include <inttypes.h>
int main() {
    uint32_t fd = 87;
    uint32_t node_id = 106;
    char pipeline[2048];
    snprintf(pipeline, sizeof(pipeline), 
        "pipewiresrc fd=%d name=vsrc path=\"%" PRIu32 "\" target-object=\"%" PRIu32 "\" ! queue ! videocrop name=crop ! videoconvert ! x265enc ! mp4mux ! filesink location=\"out.mp4\"",
        fd, node_id, node_id);
    printf("%s\n", pipeline);
    return 0;
}

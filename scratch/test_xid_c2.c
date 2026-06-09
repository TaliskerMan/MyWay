#include <gst/gst.h>
#include <stdio.h>

int main(int argc, char **argv) {
    gst_init(&argc, &argv);
    
    guint64 xid = 75497476;
    if (argc > 1) {
        xid = g_ascii_strtoull(argv[1], NULL, 10);
    }
    printf("Testing string-based XID: %lu\n", xid);

    // Format pipeline string directly with xid
    char pipeline_str[512];
    snprintf(pipeline_str, sizeof(pipeline_str),
             "ximagesrc name=vsrc xid=%lu ! videoconvert ! pngenc ! filesink location=test_xid_c2.png", xid);

    GError *error = NULL;
    GstElement *pipeline = gst_parse_launch(pipeline_str, &error);
    if (error) {
        printf("Parse error: %s\n", error->message);
        return 1;
    }

    // Set num-buffers = 1
    GstElement *vsrc = gst_bin_get_by_name(GST_BIN(pipeline), "vsrc");
    if (vsrc) {
        g_object_set(G_OBJECT(vsrc), "num-buffers", 1, NULL);
        gst_object_unref(vsrc);
    }

    gst_element_set_state(pipeline, GST_STATE_PLAYING);

    // Wait for EOS
    GstBus *bus = gst_element_get_bus(pipeline);
    GstMessage *msg = gst_bus_timed_pop_filtered(bus, GST_CLOCK_TIME_NONE, GST_MESSAGE_EOS | GST_MESSAGE_ERROR);
    if (msg) {
        if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
            GError *err = NULL;
            gchar *dbg = NULL;
            gst_message_parse_error(msg, &err, &dbg);
            printf("GStreamer Error: %s\n", err->message);
            g_clear_error(&err);
            g_free(dbg);
        } else {
            printf("Success!\n");
        }
        gst_message_unref(msg);
    }
    gst_object_unref(bus);

    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    return 0;
}

#include <gst/gst.h>
#include <stdio.h>

static gboolean
bus_call(GstBus *bus, GstMessage *msg, gpointer data) {
    if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ELEMENT) {
        const GstStructure *s = gst_message_get_structure(msg);
        if (s && gst_structure_has_name(s, "level")) {
            const GValue *rms_val = gst_structure_get_value(s, "rms");
            if (rms_val) {
                GType type = G_VALUE_TYPE(rms_val);
                printf("rms_val GType: %lu, Name: %s\n", type, g_type_name(type));
                
                if (GST_VALUE_HOLDS_LIST(rms_val)) {
                    printf("  Matches GST_VALUE_HOLDS_LIST\n");
                }
                if (GST_VALUE_HOLDS_ARRAY(rms_val)) {
                    printf("  Matches GST_VALUE_HOLDS_ARRAY\n");
                }
                if (G_VALUE_HOLDS(rms_val, G_TYPE_VALUE_ARRAY)) {
                    printf("  Matches G_TYPE_VALUE_ARRAY\n");
                    GValueArray *arr = g_value_get_boxed(rms_val);
                    if (arr) {
                        printf("    Array size: %u\n", arr->n_values);
                        for (guint i = 0; i < arr->n_values; i++) {
                            const GValue *v = g_value_array_get_nth(arr, i);
                            printf("    Value %u: type %s, db = %f\n", i, g_type_name(G_VALUE_TYPE(v)), g_value_get_double(v));
                        }
                    }
                }
                
                // Quit loop after one print
                g_main_loop_quit((GMainLoop*)data);
            }
        }
    } else if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
        g_main_loop_quit((GMainLoop*)data);
    }
    return TRUE;
}

int main(int argc, char **argv) {
    gst_init(&argc, &argv);
    
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    
    // Create pulsesrc ! level ! fakesink pipeline
    GstElement *pipeline = gst_parse_launch("pulsesrc ! audioconvert ! level name=level ! fakesink", NULL);
    
    GstBus *bus = gst_element_get_bus(pipeline);
    gst_bus_add_watch(bus, bus_call, loop);
    gst_object_unref(bus);
    
    gst_element_set_state(pipeline, GST_STATE_PLAYING);
    
    // Run main loop
    g_main_loop_run(loop);
    
    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);
    g_main_loop_unref(loop);
    return 0;
}

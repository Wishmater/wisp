#include "my_application.h"

static GLogWriterOutput log_writer(GLogLevelFlags log_level,
                                   const GLogField* fields, gsize n_fields,
                                   gpointer user_data) {
  const gchar* message = nullptr;
  for (gsize i = 0; i < n_fields; i++) {
    if (g_strcmp0(fields[i].key, "MESSAGE") == 0) {
      message = static_cast<const gchar*>(fields[i].value);
      break;
    }
  }
  if (message && g_str_has_prefix(message, "gdk_device_get_source")) {
    return G_LOG_WRITER_HANDLED;
  }
  return g_log_writer_default(log_level, fields, n_fields, user_data);
}

int main(int argc, char** argv) {
  g_log_set_writer_func(log_writer, nullptr, nullptr);
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

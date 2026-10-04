#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

// The smallest window the app lays out well in (see FinnLayout in
// lib/src/shared/layout/finn_layout.dart), and the size it opens at: wide
// enough for the docked sidebar plus a comfortable chat column.
static const gint kMinWindowWidth = 360;
static const gint kMinWindowHeight = 480;
static const gint kDefaultWindowWidth = 1180;
static const gint kDefaultWindowHeight = 780;

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// ---------------------------------------------------------------------------
// Window chrome. FinnAI draws its own title bar and window buttons in Flutter
// (lib/src/shared/widgets/finn_window_frame.dart), so the native one is
// removed and the Dart side drives the window through this channel. Setting
// FINN_NATIVE_TITLEBAR=1 keeps the desktop's own title bar instead.
// ---------------------------------------------------------------------------

// True when the window got an RGBA visual, so the app may round its corners.
static gboolean g_window_transparent = FALSE;

static gboolean use_custom_chrome() {
  const gchar* native = g_getenv("FINN_NATIVE_TITLEBAR");
  return native == nullptr || native[0] == '\0' || g_strcmp0(native, "0") == 0;
}

static FlValue* window_state(GtkWindow* window) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  GdkWindowState state =
      gdk_window != nullptr ? gdk_window_get_state(gdk_window)
                            : static_cast<GdkWindowState>(0);
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "maximized",
                           fl_value_new_bool(state & GDK_WINDOW_STATE_MAXIMIZED));
  fl_value_set_string_take(map, "fullscreen",
                           fl_value_new_bool(state & GDK_WINDOW_STATE_FULLSCREEN));
  fl_value_set_string_take(map, "focused",
                           fl_value_new_bool(state & GDK_WINDOW_STATE_FOCUSED));
  return map;
}

static gboolean window_state_event_cb(GtkWidget* widget, GdkEvent* event,
                                      gpointer user_data) {
  FlMethodChannel* channel = FL_METHOD_CHANNEL(user_data);
  g_autoptr(FlValue) state = window_state(GTK_WINDOW(widget));
  fl_method_channel_invoke_method(channel, "stateChanged", state, nullptr,
                                  nullptr, nullptr);
  return FALSE;
}

// The pointer's position in root coordinates, which the window manager needs
// to start an interactive move or resize.
static void pointer_position(GtkWindow* window, gint* x, gint* y) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = gdk_seat_get_pointer(seat);
  gdk_device_get_position(pointer, nullptr, x, y);
}

static void window_method_cb(FlMethodChannel* channel, FlMethodCall* call,
                             gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(method, "hasCustomChrome") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_bool(!gtk_window_get_decorated(window) ? TRUE : FALSE)));
  } else if (g_strcmp0(method, "isTransparent") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(
        fl_value_new_bool(g_window_transparent)));
  } else if (g_strcmp0(method, "getState") == 0) {
    g_autoptr(FlValue) state = window_state(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(state));
  } else if (g_strcmp0(method, "startDrag") == 0) {
    gint x = 0, y = 0;
    pointer_position(window, &x, &y);
    gtk_window_begin_move_drag(window, 1, x, y, GDK_CURRENT_TIME);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "startResize") == 0) {
    // 0..7: N, NE, E, SE, S, SW, W, NW (clockwise from the top).
    static const GdkWindowEdge edges[] = {
        GDK_WINDOW_EDGE_NORTH,      GDK_WINDOW_EDGE_NORTH_EAST,
        GDK_WINDOW_EDGE_EAST,       GDK_WINDOW_EDGE_SOUTH_EAST,
        GDK_WINDOW_EDGE_SOUTH,      GDK_WINDOW_EDGE_SOUTH_WEST,
        GDK_WINDOW_EDGE_WEST,       GDK_WINDOW_EDGE_NORTH_WEST};
    int64_t edge = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_INT
                       ? fl_value_get_int(args)
                       : -1;
    if (edge >= 0 && edge < 8) {
      gint x = 0, y = 0;
      pointer_position(window, &x, &y);
      gtk_window_begin_resize_drag(window, edges[edge], 1, x, y,
                                   GDK_CURRENT_TIME);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "toggleMaximize") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "toggleFullscreen") == 0) {
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
    if (gdk_window != nullptr &&
        (gdk_window_get_state(gdk_window) & GDK_WINDOW_STATE_FULLSCREEN)) {
      gtk_window_unfullscreen(window);
    } else {
      gtk_window_fullscreen(window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(call, response, &error)) {
    g_warning("Failed to send window channel response: %s", error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  const gboolean custom_chrome = use_custom_chrome();
  gboolean transparent_window = FALSE;
  gboolean use_header_bar = !custom_chrome;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (custom_chrome) {
    gtk_window_set_decorated(window, FALSE);
    gtk_window_set_title(window, "FinnAI");
    // The window's corners are rounded by the app (FinnWindowFrame clips to a
    // rounded rectangle), which only shows if what lies outside that shape is
    // transparent: an RGBA visual here, and a transparent Flutter background
    // below. Without a compositor the visual is missing and the corners stay
    // square, which is harmless.
    GdkScreen* gdk_screen = gtk_window_get_screen(window);
    GdkVisual* rgba = gdk_screen_get_rgba_visual(gdk_screen);
    if (rgba != nullptr && gdk_screen_is_composited(gdk_screen)) {
      gtk_widget_set_visual(GTK_WIDGET(window), rgba);
      gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
      transparent_window = TRUE;
      g_window_transparent = TRUE;
    }
  } else if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "FinnAI");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "FinnAI");
  }

  gtk_window_set_default_size(window, kDefaultWindowWidth,
                              kDefaultWindowHeight);

  // Without a minimum a tiling or floating window manager lets the user shrink
  // the window until the layout has no room left.
  GdkGeometry geometry;
  geometry.min_width = kMinWindowWidth;
  geometry.min_height = kMinWindowHeight;
  gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);

  // The window icon ships beside the bundle's data/ directory. A missing file
  // only means the desktop shows its generic icon, so it is not an error.
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
    g_autofree gchar* icon_path =
        g_build_filename(exe_dir, "data", "app_icon_256.png", nullptr);
    if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      gtk_window_set_icon_from_file(window, icon_path, nullptr);
    }
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, transparent_window ? "#00000000" : "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "finn_ai/window",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_cb, window, nullptr);
  g_signal_connect(window, "window-state-event",
                   G_CALLBACK(window_state_event_cb), self->window_channel);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}

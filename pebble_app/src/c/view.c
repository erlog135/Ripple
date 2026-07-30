#include <pebble.h>
#include "pdc_builder.h"

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

static Window *s_window;
static Layer  *s_canvas_layer;

// Currently displayed PDC (image or sequence). Zeroed = nothing loaded.
// Owned by this module; freed when replaced or on unload.
static PdcObject s_pdc;

// Animation state (only meaningful when s_pdc.kind == PDC_KIND_SEQUENCE)
static uint32_t  s_current_frame;
static bool      s_playing;
static AppTimer *s_anim_timer;

// Incoming PDC data buffer — dynamically allocated on PDC_SIZE message.
// Freed after parse or on error. NULL when idle.
static uint8_t  *s_data_buf = NULL;
static uint32_t  s_data_cap = 0;
static uint32_t  s_data_len = 0;

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

static void prv_canvas_update_proc(Layer *layer, GContext *ctx) {
  if (!s_pdc.image) {  // both union members share the same address — NULL check works for either
    return;
  }

  GRect  bounds   = layer_get_bounds(layer);
  GSize  pdc_size = pdc_get_bounds_size(&s_pdc);

  // Centre the graphic in the layer
  GPoint origin = GPoint(
    (bounds.size.w - pdc_size.w) / 2,
    (bounds.size.h - pdc_size.h) / 2
  );

  if (s_pdc.kind == PDC_KIND_IMAGE) {
    // Static image — draw directly
    gdraw_command_image_draw(ctx, s_pdc.image, origin);

  } else {
    // Animated sequence — draw the current frame
    uint32_t num_frames = gdraw_command_sequence_get_num_frames(s_pdc.sequence);
    if (num_frames == 0) return;

    uint32_t idx = (s_current_frame < num_frames) ? s_current_frame : 0;
    GDrawCommandFrame *frame = gdraw_command_sequence_get_frame_by_index(s_pdc.sequence, idx);
    if (frame) {
      gdraw_command_frame_draw(ctx, s_pdc.sequence, frame, origin);
    }
  }
}

// ---------------------------------------------------------------------------
// Animation timer (sequences only)
// ---------------------------------------------------------------------------

static void prv_anim_timer_callback(void *context);

static void prv_schedule_frame_timer(void) {
  if (s_anim_timer) {
    app_timer_cancel(s_anim_timer);
    s_anim_timer = NULL;
  }
  if (!s_pdc.image || s_pdc.kind != PDC_KIND_SEQUENCE || !s_playing) {
    return;
  }

  uint32_t num_frames = gdraw_command_sequence_get_num_frames(s_pdc.sequence);
  if (num_frames <= 1) return;

  uint32_t idx = s_current_frame % num_frames;
  GDrawCommandFrame *frame = gdraw_command_sequence_get_frame_by_index(s_pdc.sequence, idx);
  if (!frame) return;

  uint32_t duration = gdraw_command_frame_get_duration(frame);
  if (duration == 0) duration = 33;  // fall back to ~30 fps

  s_anim_timer = app_timer_register(duration, prv_anim_timer_callback, NULL);
}

static void prv_anim_timer_callback(void *context) {
  s_anim_timer = NULL;
  if (!s_pdc.image || s_pdc.kind != PDC_KIND_SEQUENCE || !s_playing) return;

  uint32_t num_frames = gdraw_command_sequence_get_num_frames(s_pdc.sequence);
  if (num_frames <= 1) return;

  s_current_frame = (s_current_frame + 1) % num_frames;
  layer_mark_dirty(s_canvas_layer);
  prv_schedule_frame_timer();
}

// ---------------------------------------------------------------------------
// PDC object management
// ---------------------------------------------------------------------------

// Cancel any running timer and free the current PDC object.
static void prv_clear_pdc(void) {
  if (s_anim_timer) {
    app_timer_cancel(s_anim_timer);
    s_anim_timer = NULL;
  }
  pdc_destroy(&s_pdc);
  s_pdc = (PdcObject){ 0 };
  s_current_frame = 0;
  s_playing = false;
}

// Install a newly parsed PdcObject and start playback if applicable.
static void prv_set_pdc(PdcObject new_pdc) {
  prv_clear_pdc();
  s_pdc = new_pdc;

  // Auto-play multi-frame sequences; images and single-frame sequences stay static
  if (s_pdc.kind == PDC_KIND_SEQUENCE) {
    uint32_t n = gdraw_command_sequence_get_num_frames(s_pdc.sequence);
    s_playing = (n > 1);
  }

  if (s_canvas_layer) {
    layer_mark_dirty(s_canvas_layer);
  }
  prv_schedule_frame_timer();
}

// ---------------------------------------------------------------------------
// AppMessage inbox
// ---------------------------------------------------------------------------

static void prv_reset_data_buf(void) {
  if (s_data_buf) {
    free(s_data_buf);
    s_data_buf = NULL;
  }
  s_data_cap = 0;
  s_data_len = 0;
}

static void prv_inbox_received(DictionaryIterator *iter, void *context) {
  // PDC_SIZE — JS announces total byte count; allocate the exact buffer.
  Tuple *size_tuple = dict_find(iter, MESSAGE_KEY_PDC_SIZE);
  if (size_tuple) {
    uint32_t total = (uint32_t)size_tuple->value->uint32;
    prv_reset_data_buf();
    s_data_buf = (uint8_t *)malloc(total);
    if (s_data_buf) {
      s_data_cap = total;
      APP_LOG(APP_LOG_LEVEL_INFO, "PDC_SIZE: allocating %lu bytes", (unsigned long)total);
    } else {
      APP_LOG(APP_LOG_LEVEL_ERROR, "PDC_SIZE: malloc(%lu) failed", (unsigned long)total);
    }
    return;
  }

  // PDC_DATA — accumulate chunk into the pre-allocated buffer.
  Tuple *chunk_t = dict_find(iter, MESSAGE_KEY_PDC_DATA);
  if (chunk_t) {
    if (!s_data_buf) {
      APP_LOG(APP_LOG_LEVEL_ERROR, "PDC_DATA received before PDC_SIZE — ignoring");
      return;
    }
    uint32_t chunk_len = (uint32_t)chunk_t->length;
    if (s_data_len + chunk_len <= s_data_cap) {
      memcpy(s_data_buf + s_data_len, chunk_t->value->data, chunk_len);
      s_data_len += chunk_len;
      APP_LOG(APP_LOG_LEVEL_DEBUG, "PDC chunk +%lu bytes (%lu/%lu)",
              (unsigned long)chunk_len, (unsigned long)s_data_len, (unsigned long)s_data_cap);
    } else {
      APP_LOG(APP_LOG_LEVEL_ERROR, "PDC buffer overrun — aborting transfer");
      prv_reset_data_buf();
    }
    return;
  }

  // PDC_DONE — parse and display, then free the buffer.
  Tuple *done_t = dict_find(iter, MESSAGE_KEY_PDC_DONE);
  if (done_t) {
    APP_LOG(APP_LOG_LEVEL_INFO, "PDC_DONE: %lu bytes received", (unsigned long)s_data_len);
    if (s_data_buf && s_data_len > 0) {
      PdcObject new_pdc = { 0 };
      if (pdc_build_from_data(s_data_buf, s_data_len, &new_pdc)) {
        prv_set_pdc(new_pdc);
      } else {
        APP_LOG(APP_LOG_LEVEL_ERROR, "Failed to parse PDC data");
      }
    } else {
      APP_LOG(APP_LOG_LEVEL_WARNING, "PDC_DONE with no buffered data — ignoring");
    }
    prv_reset_data_buf();
    return;
  }
}

static void prv_inbox_dropped(AppMessageResult reason, void *context) {
  APP_LOG(APP_LOG_LEVEL_ERROR, "AppMessage dropped: %d — resetting PDC buffer", (int)reason);
  prv_reset_data_buf();
}

static void prv_outbox_failed(DictionaryIterator *iter, AppMessageResult reason, void *context) {
  APP_LOG(APP_LOG_LEVEL_ERROR, "Outbox send failed: %d", (int)reason);
}

static void prv_outbox_sent(DictionaryIterator *iter, void *context) {
  APP_LOG(APP_LOG_LEVEL_INFO, "Outbox send success");
}

// ---------------------------------------------------------------------------
// Button handlers
// ---------------------------------------------------------------------------

static void prv_select_click_handler(ClickRecognizerRef recognizer, void *context) {
  // Only sequences with > 1 frame can be toggled
  if (!s_pdc.image || s_pdc.kind != PDC_KIND_SEQUENCE
      || gdraw_command_sequence_get_num_frames(s_pdc.sequence) <= 1) {
    return;
  }

  s_playing = !s_playing;
  APP_LOG(APP_LOG_LEVEL_INFO, "Playback %s", s_playing ? "resumed" : "paused");

  if (s_playing) {
    prv_schedule_frame_timer();
  } else if (s_anim_timer) {
    app_timer_cancel(s_anim_timer);
    s_anim_timer = NULL;
  }
}

static void prv_click_config_provider(void *context) {
  window_single_click_subscribe(BUTTON_ID_SELECT, prv_select_click_handler);
}

// ---------------------------------------------------------------------------
// Window lifecycle
// ---------------------------------------------------------------------------

static void prv_window_load(Window *window) {
  Layer *root = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(root);

  s_canvas_layer = layer_create(bounds);
  layer_set_update_proc(s_canvas_layer, prv_canvas_update_proc);
  layer_add_child(root, s_canvas_layer);

  window_set_click_config_provider(window, prv_click_config_provider);
}

static void prv_window_unload(Window *window) {
  prv_clear_pdc();
  layer_destroy(s_canvas_layer);
  s_canvas_layer = NULL;
}

// ---------------------------------------------------------------------------
// App lifecycle
// ---------------------------------------------------------------------------

static void prv_init(void) {
  s_window = window_create();
  window_set_background_color(s_window, GColorLightGray);
  window_set_window_handlers(s_window, (WindowHandlers) {
    .load   = prv_window_load,
    .unload = prv_window_unload,
  });
  window_stack_push(s_window, true /* animated */);

  app_message_register_inbox_received(prv_inbox_received);
  app_message_register_inbox_dropped(prv_inbox_dropped);
  app_message_register_outbox_failed(prv_outbox_failed);
  app_message_register_outbox_sent(prv_outbox_sent);

  // Open with a large inbox to accommodate chunked PDC data
  app_message_open(app_message_inbox_size_maximum(), 256);
}

static void prv_deinit(void) {
  window_destroy(s_window);
}

int main(void) {
  prv_init();
  APP_LOG(APP_LOG_LEVEL_DEBUG, "Ripple PDC viewer initialised");
  app_event_loop();
  prv_deinit();
}

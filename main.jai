#import "Basic";
#import "Window_Creation";
Simp :: #import "Simp";
Input :: #import "Input";
#import "File";
#import "Math";

#if OS == .WINDOWS {
    #import "Windows";
} else #if OS == .MACOS {
    #import "Objective_C";
    #import "Objective_C/AppKit";
}

WANTED_MSAA :: 8;

FONT_RAW :: #run read_entire_file("./OpenSans-BoldItalic.ttf");

State :: struct {
    window: Window_Type;
    window_width: int;
    window_height: int;
    quit: bool;
    font: *Simp.Dynamic_Font;

    images: [..]Image;
    current_image_id: int;
    largest_image_width := -FLOAT32_INFINITY;
    largest_image_height := -FLOAT32_INFINITY;

    zoom: float = 1;
    offset: Vector2;

    moving_mode: bool;
    overlay_mode: bool;
}

Image :: struct {
    path: string;
    texture: Simp.Texture;
}

state: State;

main :: () {
    init();

    while !state.quit {
        process_input();
        render();
        reset_temporary_storage();
    }
}

render :: () {
    Simp.clear_render_target(.2, .2, .2, 1);

    Simp.immediate_begin();

    if state.images.count > 0 {
        current_image := state.images[state.current_image_id];

        Simp.set_shader_for_images(*current_image.texture);

        scale := min(
            cast(float, state.window_width) / state.largest_image_width,
            cast(float, state.window_height) / state.largest_image_height
        ) * state.zoom;

        image_new_width := current_image.texture.width * scale;
        image_new_height := current_image.texture.height * scale;

        padding_y := (state.window_height - image_new_height) / 2;
        padding_x := (state.window_width - image_new_width) / 2;

        Simp.immediate_quad(
            padding_x + state.offset.x,
            padding_y - state.offset.y,
            xx (image_new_width) + padding_x + state.offset.x,
            xx (image_new_height) + padding_y - state.offset.y,
            { 1, 1, 1, 1 },
        );

        page_text := tprint("%/%", state.current_image_id + 1, state.images.count);
        page_text_width := Simp.prepare_text(state.font, page_text);

        center := cast(float) state.window_width / 2 - page_text_width / 2;

        Simp.set_shader_for_color(enable_blend = true);
        Simp.immediate_quad(
            center - 10,
            40,
            cast(float) page_text_width + center + 10,
            cast(float) 50 + 20,
            { 0.3, 0.3, 0.3, 0.3 },
        );

        Simp.draw_prepared_text(
            state.font,
            xx center,
            50,
        );
    }

    if state.overlay_mode || state.images.count == 0 {
        { // Help
            HEIGHT :: 50;

            text_width := Simp.prepare_text(
                state.font,
                "LMB - toggle overlay, MMB - move image, RMB - reset image, SCROLL - zoom, BACKSPACE - remove image",
            );

            if text_width < state.window_width {
                Simp.set_shader_for_color(enable_blend = true);
                Simp.immediate_quad(
                    0,
                    cast(float) state.window_height - HEIGHT,
                    xx state.window_width,
                    cast(float) state.window_height,
                    { 0.3, 0.3, 0.3, 0.5 },
                );
                Simp.draw_prepared_text(
                    state.font,
                    state.window_width / 2 -text_width / 2,
                    state.window_height - (HEIGHT - state.font.character_height),
                );
            }
        }

        if state.images.count > 0 { // Path
            path_width := Simp.prepare_text(
                state.font,
                state.images[state.current_image_id].path,
            );

            Simp.set_shader_for_color(enable_blend = true);
            Simp.immediate_quad(
                0,
                0,
                cast(float) state.window_width,
                cast(float) 10 + state.font.character_height + 10,
                { 0.3, 0.3, 0.3, 0.5 },
            );

            Simp.draw_prepared_text(
                state.font,
                state.window_width / 2 - path_width / 2,
                10,
            );
        }
    }

    Simp.immediate_flush();

    Simp.swap_buffers(state.window);
}

add_image :: (path: string) {
    texture: Simp.Texture;
    Simp.texture_load_from_file(*texture, path, srgb = false);

    array_add(*state.images, Image.{ copy_string(path), texture });

    state.current_image_id = state.images.count - 1;

    for image: state.images {
        state.largest_image_width = max(cast(float) image.texture.width, state.largest_image_width);
        state.largest_image_height = max(cast(float) image.texture.height, state.largest_image_height);
    }
}

remove_image :: () {
    if state.images.count == 0 {
        return;
    }

    current_image := state.images[state.current_image_id];

    Simp.texture_destroy(*current_image.texture);
    free(current_image.path);

    array_ordered_remove_by_index(*state.images, state.current_image_id);

    state.current_image_id = max(state.current_image_id - 1, 0);;
}

process_input :: () {
    Input.update_window_events();

    for Input.get_window_resizes() {
        Simp.update_window(it.window);

        if it.window == state.window {
            should_reinit := (it.width != state.window_width)
            || (it.height != state.window_height);

            state.window_width  = it.width;
            state.window_height = it.height;
        }
    }

    for event: Input.events_this_frame {
        if event.type == {
            case .QUIT;
                state.quit = true;
            case .WINDOW;
                if event.window_event_type == {
                    case .MOVED_TO_BACKGROUND;
                        Simp.disable_window(event.window);
                        state.window = WT.INVALID_WINDOW;

                    case .MOVED_TO_FOREGROUND;
                        Simp.enable_window(event.window);
                        state.window = event.window;
                }
            case .DRAG_AND_DROP_FILES;
                for file_path: event.files {
                    add_image(file_path);
                }
            case .KEYBOARD;
                if event.key_code == {
                    case .ARROW_RIGHT;
                        if event.key_pressed && state.images.count - 1 > state.current_image_id {
                            state.current_image_id += 1;
                        }
                    case .ARROW_LEFT;
                        if event.key_pressed && state.current_image_id > 0 {
                            state.current_image_id -= 1;
                        }
                    case .F1;
                        if event.key_pressed {
                            state.overlay_mode = !state.overlay_mode;
                        }
                    case .BACKSPACE;
                        if event.key_pressed {
                            remove_image();
                        }
                    case .MOUSE_BUTTON_LEFT;
                        #if OS == .MACOS {
                            state.moving_mode = xx event.key_pressed;
                        } else {
                            if event.key_pressed {
                                state.overlay_mode = !state.overlay_mode;
                            }
                        }
                    case .MOUSE_BUTTON_MIDDLE;
                        state.moving_mode = xx event.key_pressed;
                    case .MOUSE_BUTTON_RIGHT;
                        state.offset = {};
                        state.zoom = 1;
                }
            case .MOUSE_WHEEL;
                SENSITIVITY :: 0.01;
                state.zoom += event.wheel_delta * SENSITIVITY;
                state.zoom = max(state.zoom, 1);
        }
    }

    if state.moving_mode {
        state.offset.x += Input.mouse_delta_x;
        state.offset.y += Input.mouse_delta_y;
    }
}

init :: () {
    #if OS == .WINDOWS {
        Windows.SetProcessDPIAware();
        Windows.timeBeginPeriod(1);
    }

    state.window = create_window(800, 600, "pcompa", wanted_msaa = WANTED_MSAA);
    Simp.prepare_window(state.window, WANTED_MSAA);
    state.window_width, state.window_height = Simp.get_render_dimensions(state.window);

    #if OS == .WINDOWS {
        Windows.DragAcceptFiles(state.window, cast(Windows.BOOL) true);
    } else #if OS == .MACOS {
        #import "Objective_C";
        #import "Objective_C/AppKit";
        types := NSArray(NSPasteboardType).arrayWithObject(NSPasteboardTypeFileURL);
        NSView.registerForDraggedTypes(state.window, types);
    }

    Simp.set_render_target(state.window);

    font_bytes: []u8;
    font_bytes.count = FONT_RAW.count;
    font_bytes.data = FONT_RAW.data;
    state.font = Simp.get_font_at_size(font_bytes, 20);
}

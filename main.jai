#import "Basic";
#import "Window_Creation";
Simp :: #import "Simp";
Input :: #import "Input";
#import "File";

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
    images: [..]Simp.Texture;
    current_image: int;
}

state: State;

main :: () {
    init();

    while !state.quit {
        process_input();
        render();
    }
}

render :: () {
    Simp.clear_render_target(.15, .08, .08, 1);

    Simp.immediate_begin();

    if state.images.count > 0 {
        current_image := state.images[state.current_image];

        image_aspect := cast(float, current_image.width) / cast(float, current_image.height);

        Simp.set_shader_for_images(*current_image);

        scale := min(
            cast(float, state.window_width) / current_image.width,
            cast(float, state.window_height) / current_image.height
        );

        image_new_width := current_image.width * scale;
        image_new_height := current_image.height * scale;

        padding_y := (state.window_height - image_new_height) / 2;
        padding_x := (state.window_width - image_new_width) / 2;

        Simp.immediate_quad(
            padding_x,
            padding_y,
            xx (image_new_width) + padding_x,
            xx (image_new_height) + padding_y,
            { 1, 1, 1, 1 },
        );

        Simp.draw_text(state.font, 10, 10, tprint("%/%", state.current_image + 1, state.images.count));
    }

    Simp.immediate_flush();

    Simp.swap_buffers(state.window);
}

add_image :: (path: string) {
    texture: Simp.Texture;
    Simp.texture_load_from_file(*texture, path, srgb = false);

    array_add(*state.images, texture);

    state.current_image = state.images.count - 1;
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
                        if event.key_pressed && state.images.count - 1 > state.current_image {
                            state.current_image += 1;
                        }
                    case .ARROW_LEFT;
                        if event.key_pressed && state.current_image > 0 {
                            state.current_image -= 1;
                        }
                }
        }
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

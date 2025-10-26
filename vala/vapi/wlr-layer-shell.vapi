[CCode (cheader_filename = "wlr-layer-shell-unstable-v1-client-protocol.h")]
namespace Wlr {

	[CCode (cname = "zwlr_layer_shell_v1")]
	public class LayerShellV1 : GLib.Object {
		[CCode (cname = "zwlr_layer_shell_v1_get_layer_surface")]
		public LayerSurfaceV1 get_layer_surface (Wl.Surface surface, Wl.Output? output, uint32 layer, string @namespace);

		[CCode (cname = "zwlr_layer_shell_v1_destroy")]
		public void destroy ();

		[CCode (cname = "zwlr_layer_shell_v1_set_user_data")]
		public void set_user_data (void* user_data);

		[CCode (cname = "zwlr_layer_shell_v1_get_user_data")]
		public void* get_user_data ();

		[CCode (cname = "zwlr_layer_shell_v1_get_version")]
		public uint32 get_version ();
	}

	[CCode (cname = "zwlr_layer_surface_v1")]
	public class LayerSurfaceV1 : GLib.Object {
		[CCode (cname = "zwlr_layer_surface_v1_set_size")]
		public void set_size (uint32 width, uint32 height);

		[CCode (cname = "zwlr_layer_surface_v1_set_anchor")]
		public void set_anchor (uint32 anchor);

		[CCode (cname = "zwlr_layer_surface_v1_set_exclusive_zone")]
		public void set_exclusive_zone (int32 zone);

		[CCode (cname = "zwlr_layer_surface_v1_set_margin")]
		public void set_margin (int32 top, int32 right, int32 bottom, int32 left);

		[CCode (cname = "zwlr_layer_surface_v1_set_keyboard_interactivity")]
		public void set_keyboard_interactivity (uint32 keyboard_interactivity);

		[CCode (cname = "zwlr_layer_surface_v1_get_popup")]
		public void get_popup (Xdg.Popup popup);

		[CCode (cname = "zwlr_layer_surface_v1_ack_configure")]
		public void ack_configure (uint32 serial);

		[CCode (cname = "zwlr_layer_surface_v1_destroy")]
		public void destroy ();

		[CCode (cname = "zwlr_layer_surface_v1_set_layer")]
		public void set_layer (uint32 layer);

		[CCode (cname = "zwlr_layer_surface_v1_set_user_data")]
		public void set_user_data (void* user_data);

		[CCode (cname = "zwlr_layer_surface_v1_get_user_data")]
		public void* get_user_data ();

		[CCode (cname = "zwlr_layer_surface_v1_get_version")]
		public uint32 get_version ();

		[CCode (cname = "zwlr_layer_surface_v1_add_listener")]
		public int add_listener (LayerSurfaceV1Listener listener, void* data);
	}

	[CCode (cname = "zwlr_layer_shell_v1_error")]
	public enum LayerShellV1Error {
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_ERROR_ROLE")]
		ROLE,
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_ERROR_INVALID_LAYER")]
		INVALID_LAYER,
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_ERROR_ALREADY_CONSTRUCTED")]
		ALREADY_CONSTRUCTED
	}

	[CCode (cname = "zwlr_layer_shell_v1_layer")]
	public enum LayerShellV1Layer {
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND")]
		BACKGROUND,
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM")]
		BOTTOM,
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_LAYER_TOP")]
		TOP,
		[CCode (cname = "ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY")]
		OVERLAY
	}

	[CCode (cname = "zwlr_layer_surface_v1_keyboard_interactivity")]
	public enum LayerSurfaceV1KeyboardInteractivity {
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE")]
		NONE,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_EXCLUSIVE")]
		EXCLUSIVE,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_ON_DEMAND")]
		ON_DEMAND
	}

	[CCode (cname = "zwlr_layer_surface_v1_error")]
	public enum LayerSurfaceV1Error {
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_SURFACE_STATE")]
		INVALID_SURFACE_STATE,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_SIZE")]
		INVALID_SIZE,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_ANCHOR")]
		INVALID_ANCHOR,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ERROR_INVALID_KEYBOARD_INTERACTIVITY")]
		INVALID_KEYBOARD_INTERACTIVITY
	}

	[CCode (cname = "zwlr_layer_surface_v1_anchor")]
	public enum LayerSurfaceV1Anchor {
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP")]
		TOP = 1,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM")]
		BOTTOM = 2,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT")]
		LEFT = 4,
		[CCode (cname = "ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT")]
		RIGHT = 8
	}

	[CCode (cname = "zwlr_layer_surface_v1_listener", has_type_id = false)]
	public struct LayerSurfaceV1Listener {
		[CCode (cname = "configure")]
		public unowned LayerSurfaceV1ConfigureCallback configure;

		[CCode (cname = "closed")]
		public unowned LayerSurfaceV1ClosedCallback closed;
	}

	[CCode (cname = "zwlr_layer_surface_v1_configure_callback", has_target = false)]
	public delegate void LayerSurfaceV1ConfigureCallback (void* data, LayerSurfaceV1 surface, uint32 serial, uint32 width, uint32 height);

	[CCode (cname = "zwlr_layer_surface_v1_closed_callback", has_target = false)]
	public delegate void LayerSurfaceV1ClosedCallback (void* data, LayerSurfaceV1 surface);
}
[CCode (cheader_filename = "xdg-shell-client-protocol.h")]
namespace Xdg {
	[CCode (cname = "xdg_popup")]
	public class Popup : GLib.Object {
	}
}
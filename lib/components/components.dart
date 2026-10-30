/// Picksell Mobile Component System — one import for screens:
/// `import '../components/components.dart';`
///
/// 01 Shared system (SYS-C01…C20) + form inputs. Commerce, buyer and
/// logistics components live in their own folders as they're built.
library;

export '../core/network/api_client.dart' show ApiException;

export '../core/status/order_status.dart';
export '../core/theme/ps_colors.dart';
export '../core/theme/ps_tokens.dart';
export '../core/theme/ps_typography.dart';
export '../core/validation/validators.dart';

export 'shared/forms/ps_checkbox_tile.dart';
export 'shared/forms/ps_date_field.dart';
export 'shared/forms/ps_otp_input.dart';
export 'shared/forms/ps_password_checklist.dart';
export 'shared/forms/ps_phone_field.dart';
export 'shared/forms/ps_text_field.dart';
export 'shared/ps_app_shell.dart'; //            SYS-C01
export 'shared/ps_top_bar.dart'; //              SYS-C02
export 'shared/ps_bottom_nav.dart'; //           SYS-C03
export 'shared/ps_pick_thread.dart'; //          SYS-C04
export 'shared/ps_status_badge.dart'; //         SYS-C05
export 'shared/ps_buttons.dart'; //              SYS-C06, C07, C08
export 'shared/ps_dialogs.dart'; //              SYS-C09
export 'shared/ps_bottom_sheet.dart'; //         SYS-C10
export 'shared/ps_toast.dart'; //                SYS-C11
export 'shared/states/ps_loading_state.dart'; // SYS-C12
export 'shared/states/ps_empty_state.dart'; //   SYS-C13
export 'shared/states/ps_error_state.dart'; //   SYS-C14
export 'shared/states/ps_offline_state.dart'; // SYS-C15
export 'shared/ps_notification_center.dart'; //  SYS-C16
export 'shared/ps_search_bar.dart'; //           SYS-C17
export 'shared/ps_filter_sort.dart'; //          SYS-C18
export 'shared/ps_segmented_control.dart'; //    SYS-C19
export 'shared/ps_refreshable.dart'; //          SYS-C20
export 'shared/states/ps_state_layout.dart';
export 'shared/ps_async_view.dart';
export 'shared/ps_card.dart';

// 02 Commerce (COM-C01…C20)
export 'commerce/ps_address_card.dart'; //         COM-C18
export 'commerce/ps_cart_item.dart'; //            COM-C12, C13
export 'commerce/ps_checkout_tiles.dart'; //       COM-C15, C16
export 'commerce/ps_cost_breakdown.dart'; //       COM-C17
export 'commerce/ps_home_sections.dart';
export 'commerce/ps_order_card.dart'; //           COM-C20
export 'commerce/ps_order_summary.dart'; //        COM-C19
export 'commerce/ps_price.dart'; //                COM-C05, C06
export 'commerce/ps_product_card.dart'; //         COM-C01
export 'commerce/ps_product_config_sheet.dart'; // COM-C10, C11
export 'commerce/ps_product_gallery.dart'; //      COM-C02
export 'commerce/ps_product_image.dart';
export 'commerce/ps_quantity_stepper.dart'; //     COM-C08
export 'commerce/ps_rating.dart'; //               COM-C03
export 'commerce/ps_seller_card.dart'; //          COM-C04
export 'commerce/ps_variation_selector.dart'; //   COM-C09
export 'commerce/ps_voucher.dart'; //              COM-C14
export 'commerce/ps_wishlist_button.dart'; //      COM-C07

// 03 Buyer logistics & account (BUY-C*, BUY-A*)
export 'buyer/ps_account.dart'; //                 BUY-A01, A02
export 'buyer/ps_address_fields.dart'; //          BUY-A03
export 'buyer/ps_order_actions.dart'; //           BUY-C09, C10, C13, C14
export 'buyer/ps_tracking.dart'; //                BUY-C01, C03…C08, C12

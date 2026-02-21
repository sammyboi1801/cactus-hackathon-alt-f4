// lib/tools/tool_registry.dart

/// Single source of truth for all available tool names.
/// Injected into:
///   - PlannerPromptBuilder (so Planner only suggests real tools)
///   - Stage 2 FunctionGemma (so executor only calls real tools)
///   - Dart tool dispatcher (maps names → actual functions)
class ToolRegistry {
  ToolRegistry._(); // non-instantiable

  static const List<String> allTools = [
    // --- File Tools (file_tools.dart) ---
    'search_files_semantic',   // semantic embedding search over indexed files
    'search_files_recent',     // recency-sorted file search
    'search_files_by_type',    // filter by mime type

    // --- Photo Tools (photo_tools.dart) ---
    'search_photos_semantic',  // semantic caption/embedding search over photos
    'search_photos_by_date',   // filter photos by date range

    // --- Automation Tools (automation_tools.dart) ---
    'toggle_wifi',             // enable/disable WiFi
    'toggle_bluetooth',        // enable/disable Bluetooth
    'toggle_flashlight',       // toggle device torch
    'open_app',                // launch app by package name
    'get_battery_status',      // read battery level and charging state

    // --- Clipboard Tools (clipboard_tools.dart) ---
    'copy_text',               // write text to clipboard
    'read_clipboard',          // read current clipboard content
  ];

  /// Quick lookup: does a tool name actually exist?
  static bool exists(String toolName) => allTools.contains(toolName);

  /// Filter a list of suggested tool names to only those that actually exist.
  /// Used to sanitize Planner output before passing to Stage 2.
  static List<String> filterValid(List<String> suggested) =>
      suggested.where(exists).toList();
}
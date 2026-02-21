// lib/services/planner/USAGE_EXAMPLE.dart
//
// This file shows how to wire PlannerPipeline into your app.
// It is NOT a runnable file — it's a reference for integration.

// ---------------------------------------------------------------------------
// 1. Register PlannerPipeline as a provider (e.g. with Provider package)
// ---------------------------------------------------------------------------
//
// In main.dart or your top-level widget:
//
// void main() {
//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => PlannerPipeline()..initialize(),
//       child: const MyApp(),
//     ),
//   );
// }

// ---------------------------------------------------------------------------
// 2. Observe state in your chat UI widget
// ---------------------------------------------------------------------------
//
// class ChatScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final pipeline = context.watch<PlannerPipeline>();
//
//     return switch (pipeline.state.status) {
//       PlannerPipelineStatus.downloading => LinearProgressIndicator(
//           value: pipeline.state.downloadProgress,
//         ),
//       PlannerPipelineStatus.ready || PlannerPipelineStatus.planning =>
//           _buildChatUI(context, pipeline),
//       PlannerPipelineStatus.error =>
//           Text('Error: ${pipeline.state.statusMessage}'),
//       _ => const CircularProgressIndicator(),
//     };
//   }
// }

// ---------------------------------------------------------------------------
// 3. Send a message and route the result
// ---------------------------------------------------------------------------
//
// Future<void> onUserSend(String userMessage) async {
//   final pipeline = context.read<PlannerPipeline>();
//
//   final result = await pipeline.plan(userMessage);
//
//   // Show chat response in UI IMMEDIATELY — before Stage 2 runs
//   chatMessages.add(AssistantMessage(text: result.chatResponse));
//
//   // Route to Stage 2 only if tools are needed
//   if (result.plannerOutput.requiresToolExecution) {
//     final toolResult = await stage2Coordinator.execute(result.plannerOutput);
//     chatMessages.add(ToolResultMessage(toolResult: toolResult));
//   }
// }

// ---------------------------------------------------------------------------
// 4. Complete PlannerOutput JSON examples (what you'll receive)
// ---------------------------------------------------------------------------

// User: "Find my resume"
// PlannerOutput.toJson() =>
// {
//   "intent": "file_search",
//   "reasoning_summary": "User wants to locate a resume document from device storage.",
//   "chat_response": "On it! Searching your storage for recent resumes.",
//   "candidate_tools": ["search_files_semantic", "search_files_recent"],
//   "arguments": {
//     "query": "resume",
//     "priority": "recent",
//     "mime_filter": "application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document"
//   },
//   "confidence": 0.95
// }
// plannerOutput.requiresToolExecution == true → send to Stage 2

// User: "What is 2 + 2?"
// PlannerOutput.toJson() =>
// {
//   "intent": "user_question",
//   "reasoning_summary": "Simple math question answerable without tools.",
//   "chat_response": "That is 4!",
//   "candidate_tools": [],
//   "arguments": {},
//   "confidence": 0.99
// }
// plannerOutput.requiresToolExecution == false → show chatResponse directly, skip Stage 2

// ---------------------------------------------------------------------------
// 5. Handoff contract to Stage 2 (FunctionGemma)
// ---------------------------------------------------------------------------
//
// Stage 2 receives the full PlannerOutput.
// It picks ONE tool from candidate_tools and executes it.
//
// class Stage2Coordinator {
//   Future<ToolResult> execute(PlannerOutput plannerOutput) async {
//     // FunctionGemma selects the best tool from candidate_tools
//     // using the reasoning_summary and arguments as context
//     final selectedTool = await functionGemma.selectTool(
//       candidateTools: plannerOutput.candidateTools,
//       reasoningSummary: plannerOutput.reasoningSummary,
//       arguments: plannerOutput.arguments,
//     );
//
//     // Execute the Dart function
//     return await toolDispatcher.dispatch(
//       toolName: selectedTool,
//       arguments: plannerOutput.arguments,
//     );
//   }
// }

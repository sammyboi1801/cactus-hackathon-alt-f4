# Local-First Android Agent


https://github.com/user-attachments/assets/d01b0b31-08e6-4067-9e60-08943190633d


## Project Overview

This project showcases a cutting-edge, local-first agentic workflow designed for Android devices, leveraging **Flutter** for a cross-platform UI and the **Cactus Compute SDK** for on-device AI inference. It demonstrates a sophisticated two-stage "Router-Solver" architecture that redefines the edge-cloud frontier by prioritizing privacy, speed, and efficiency through intelligent, on-device model routing and execution.

The agent delivers flawless on-device execution, ensuring that sensitive user data remains private and interactions are nearly instantaneous, free from cloud latency.

## Features

*   **Local-First Processing:** All AI inference occurs directly on the Android device, guaranteeing user data privacy and minimizing latency.
*   **Two-Stage Agentic Architecture:** An intelligent routing mechanism powered by specialized AI models optimizes resource usage and response times.
*   **Dynamic Escalation:** Seamlessly switches between a lightweight router model for tool execution and a more powerful conversational model for complex queries.
*   **Comprehensive Tooling:** Built-in capabilities to interact with device features such as file search, photo management, system settings (Wi-Fi, Bluetooth, flashlight), app launching, battery status, and clipboard operations.
*   **Intuitive User Interface:** A responsive Flutter application provides a smooth chat-based interaction experience.

## Architecture: Intelligent Routing with FunctionGemma & Gemini/Qwen

The core innovation lies in its agentic workflows, which utilize local-first reasoning through a two-stage process:

1.  **Stage 1: The Router (FunctionGemma)**
    *   **Model:** Powered by **FunctionGemma** (e.g., `functiongemma-270m`, although the current implementation in `AgentService` uses `qwen3-1.7` as a placeholder for a tool-calling model).
    *   **Role:** This lightweight model acts as the primary decision-maker. Upon receiving a user message, FunctionGemma's sole responsibility is **intelligent routing**. It analyzes the user's intent to determine if a specific device tool (e.g., "search for my resume", "turn off Wi-Fi") is required.
    *   **Execution:** If a tool call is identified, FunctionGemma generates the precise structured arguments required for that tool. This process is extremely fast and efficient, as it avoids invoking a larger, more resource-intensive model unless absolutely necessary.
    *   **Local-First Reasoning:** By running FunctionGemma entirely on-device via Cactus Compute, the agent achieves unparalleled speed and ensures that all intent analysis and tool-call routing happen privately on the user's device.

2.  **Stage 2: The Solver (Gemini/Qwen)**
    *   **Model:** A larger, more capable conversational model (e.g., **Gemini** or **Qwen3-1.7b**, as configured in `AgentService`).
    *   **Role:** If FunctionGemma determines that the user's request is purely conversational and does not require a specific tool (e.g., "Tell me a joke", "What's the weather like?"), the system *dynamically escalates* the request to the Solver.
    *   **Execution:** This model generates a natural, nuanced language response, providing the conversational depth that FunctionGemma is not designed for.
    *   **Edge-Cloud Frontier:** This dynamic escalation demonstrates how the architecture fundamentally relies on FunctionGemma and Cactus Compute to redefine the edge-cloud frontier. Complex conversational tasks that might traditionally require cloud-based LLMs can still be handled efficiently, with the intelligent local router ensuring that the larger model is only engaged when truly needed, reducing overall resource consumption and improving responsiveness.

This intelligent routing logic ensures optimal performance, resource utilization, and data privacy by performing as much processing as possible on the device ("local-first") and only engaging larger models for tasks that genuinely require their capabilities.

## Technologies Used

*   **Flutter:** UI framework for building natively compiled applications for mobile, web, and desktop from a single codebase.
*   **Dart:** The programming language for Flutter.
*   **Cactus Compute SDK:** A powerful SDK enabling efficient on-device execution of large language models (LLMs) and other AI models. It forms the backbone of the local-first AI capabilities.
*   **FunctionGemma:** A highly efficient, small language model optimized for function calling and tool routing on-device.
*   **Qwen3-1.7b (or Gemini equivalent):** A larger language model used for more complex conversational interactions.
*   **`pubspec.yaml` Dependencies:**
    *   `cactus: ^1.3.0` (Cactus Compute SDK)
    *   `flutter` (SDK)
    *   `cupertino_icons`
    *   `flutter_lints` (development dependency)

## Getting Started

To get this project up and running on your local machine, follow these steps.

### Prerequisites

*   **Flutter SDK:** Ensure you have Flutter installed. Refer to the [official Flutter documentation](https://flutter.dev/docs/get-started/install) for installation instructions.
*   **Android Studio / Xcode:** Required for building and running on Android/iOS devices or emulators.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/frontend.git
    cd frontend
    ```
2.  **Fetch dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Run the application:**
    ```bash
    flutter run
    ```
    This will launch the application on your connected device or emulator. The models (`FunctionGemma` and `Qwen3-1.7b`) will be downloaded and initialized on the first run, which may take some time depending on your internet connection and device performance.

## Usage

Interact with the agent via the chat interface. Type your queries or commands, and observe how the agent intelligently routes your requests to either execute a device tool (e.g., "find photos of dogs") or engage in a natural conversation (e.g., "tell me a fun fact").

## Contributing

Contributions are welcome! Please feel free to open issues or submit pull requests.

## License

This project is licensed under the [LICENSE NAME OR LINK TO LICENSE FILE].

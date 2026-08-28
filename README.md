# Buck Mobile Application

This is a [Flutter](https://flutter.dev) mobile application for **Buck | The Budget Tracker**.

## Getting Started

### 1️⃣ First, clone the repository using GitHub Desktop or Git Bash

In using Git CMD or Git Bash, use the command below:

```bash
# Git CMD or Git Bash
git clone https://github.com/Scorch879/Buck-Mobile.git

# GitHub Desktop
Press File > Clone Repository > Select Buck-Mobile Repository
```

```bash
# Get Flutter dependencies
flutter pub get
```

### For Firebase / Backend integration, ensure you configure the required plugins:

```bash
# Install core Firebase / Supabase packages
flutter pub add firebase_core firebase_auth
# or for Supabase backend
flutter pub add supabase_flutter
```

### 2️⃣ Run the development application:

```bash
# Run on connected device / emulator
flutter run

# Or target a specific device (e.g. Chrome, iOS simulator, Android emulator)
flutter run -d chrome
flutter run -d android
flutter run -d ios
```

---

# Expense Forecasting System

## Overview
A modular system designed to track expenses and forecast spending using AI-powered components. The architecture
integrates mobile user interfaces with backend processing and specialized machine learning models.

---

## Architecture Components

### 1️⃣ Mobile Client (Flutter + Firebase / Supabase Auth)
- **Purpose**: Mobile user interaction interface for expense logging, goal management, and visualization
- **Key Features**:
  - Expense input forms with real-time validation
  - Interactive UI for setting financial goals (Normal/Moderate/Aggressive profiles)
  - Data visualization dashboard showcasing spending forecasts and insights
  - Authentication system using Firebase / Supabase identity services

### 2️⃣ Backend (Python FastAPI/Flask / Supabase)
- **Purpose**: Core business logic processing and API gateway
- **Responsibilities**:
  ```python
  • Processes raw expense data from client
  • Orchestrates AI model workflows for predictions
  • Coordinates data storage across all components
  • Serves as communication bridge between client/UI and ML services
  ```

### 3️⃣ AI Engine (Python)
- **Powered by Three Integrated Machine Learning Models**:
  - **OpenAI Embedding API**: Auto-categorization of expenses using advanced NLP embeddings

  ```mermaid
  graph TD;
    A[Expense Text] --> B((Embedding));
    B --> C{Category Prediction};
    C --> D[Lifestyle Expenses];
    C --> E[Utilities];
    C --> F[Dining Out];
  ```

  - **XGBoost Classifier**: Predicts adjustment multipliers based on:
    ```python
      • User's historical saving patterns
      • Financial goal profiles (Normal/Moderate/Aggressive)
      • Behavioral spending signatures
    ```

  - **Facebook Prophet**:
    - Time-series forecasting of monthly spending trends
    - Adapts predictions dynamically to detect behavioral changes
    - Incorporates emergency scenario adjustments

---

## System Architecture

| Component         | Function                                       |
|-------------------|-----------------------------------------------|
| Mobile Client     | Mobile user interface & data display           |
| Backend           | Core processing & API management               |
| AI Engine          | Auto-categorization, prediction & forecasting |

---

## Technologies Used

| Component | Stack Highlights |
|-----------|------------------|
| Mobile Client | Flutter, Dart, Firebase Authentication / Supabase |
| Backend       | Python (FastAPI/Flask), PostgreSQL (Supabase), Redis caching |
| AI Engine     | XGBoost, OpenAI API, Prophet time-series library |

---

## System Features

- **Auto-expense categorization** using transformer embeddings
- **Dynamic forecasting** adapting to user behavioral patterns
- **Multi-model integration** for comprehensive financial insights
- **Secure authentication** ensuring encrypted transactions

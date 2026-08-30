# Xirfadle Mobile App Specifications (Flutter)

## System Role & Objective
You are a Principal Flutter & Cross-Platform Mobile Engineer. Build a production-ready, highly modular Flutter application for **Xirfadle**, a local service-matching platform. The single Flutter codebase must support two distinct user modes/views: **Customer Mode** and **Skilled Person (Provider) Mode**, driving a multi-role experience powered by ASP.NET Core Web API backend endpoints.


## Technical Stack Guidelines
* **Framework:** Flutter (latest stable release)
* **Language:** Dart
* **State Management & Architecture:** Feature-First Architecture using **Riverpod** for reactive state handling.
* **Networking:** `dio` for HTTP requests with custom interceptors for JWT injection and token refresh.
* **Local Storage:** `flutter_secure_storage` for token persistence and `shared_preferences` for app preferences.
* **Location & Maps:** `geolocator` and `google_maps_flutter` (or `flutter_map`) for location picking and distance display.


## App Modes & Workflow Specifications

### 1. Unified Authentication & Role Selection
* **Animated Splash & Auth Flow:** Phone number registration/login via API (`POST /api/v1/auth/login`).
* **Role Switcher / Navigation Guard:** Upon authentication, inspect `Role` claim from the JWT:
  * If `Customer` $\rightarrow$ route directly to **Customer View Dashboard**.
  * If `Provider` $\rightarrow$ route directly to **Skilled Person Dashboard**.
  * If dual role permitted, provide a profile toggle to switch operational modes.


### 2. Customer Mode Workflow

#### **A. Service Discovery & Browsing (`/customer/home`)**
* **Category Grid:** Visual categories (Plumbing, Electrical, Tutoring) retrieved from `GET /api/v1/customer/categories`.
* **Provider Search & Profiles:** 
  * List available providers sorted by rating and proximity (`GET /api/v1/customer/providers`).
  * Provider detail screen featuring bio, average star rating, total job reviews, and specialty tags (`GET /api/v1/customer/providers/{id}`).

#### **B. Service Request Submission (`/customer/create-request`)**
* **Request Creation Form:**
  * Category selector.
  * Description input (issue details, timing preference).
  * Address picker (Map pin or manually entered address).
* **Submission Action:** Triggers `POST /api/v1/customer/requests` with status initialized to `PendingAdminReview`.
* **Status Confirmation Screen:** Informs the customer that an admin will call them off-platform to confirm job details and pricing.

#### **C. My Requests & Live Status Tracker (`/customer/my-requests`)**
* List of submitted jobs with real-time status badges:
  * `PendingAdminReview` $\rightarrow$ "Admin Reviewing" (Yellow)
  * `ConfirmedByAdmin` / `Assigned` $\rightarrow$ "Matching Provider" (Blue)
  * `AcceptedByProvider` $\rightarrow$ "Provider Assigned & Confirmed" (Green)
  * `Completed` $\rightarrow$ "Completed — Tap to Rate"
* **Rating & Review Modal:** Triggers `POST /api/v1/customer/reviews` upon job completion.


### 3. Skilled Person (Provider) Mode Workflow

#### **A. Provider Dashboard & Duty Toggle (`/provider/home`)**
* **Availability Toggle:** Switch `IsAvailable` online/offline state to notify admins of willingness to receive dispatches.
* **Active Assigned Tasks Banner:** Prominent notification card showing newly dispatched tasks awaiting provider response.

#### **B. Dispatched Task Accept / Reject Flow (`/provider/requests`)**
* **Incoming Job Request Card:** Displays customer address, service category, problem description, and `AgreedPrice` set by the admin.
* **Action Controls:**
  * **Accept Button:** Calls `PATCH /api/v1/provider/requests/{id}/respond` with `status: AcceptedByProvider`. Transitions job to active state.
  * **Reject Button:** Calls `PATCH /api/v1/provider/requests/{id}/respond` with `status: RejectedByProvider` + reason prompt. Immediately alerts admin portal for re-dispatch.

#### **C. Job Completion Flow (`/provider/active-job`)**
* Step-by-step job tracker (`Accepted` $\rightarrow$ `In Progress` $\rightarrow$ `Completed`).
* **Mark Complete Action:** Calls `PATCH /api/v1/provider/requests/{id}/complete` to finish task and trigger customer review availability.


## Architecture & Directory Layout (Feature-First)

lib/
├── app/
│   ├── config/ (routes, themes, constants)
│   └── main.dart
├── core/
│   ├── network/ (dio_client.dart, api_interceptors.dart)
│   ├── storage/ (secure_storage_service.dart)
│   └── widgets/ (custom_buttons, loading_indicators, status_badges)
└── features/
├── auth/
│   ├── data/ (auth_repository.dart)
│   ├── bloc/ (auth_bloc.dart, auth_event.dart, auth_state.dart)
│   └── presentation/ (login_screen.dart, register_screen.dart)
├── customer/
│   ├── data/ (customer_repository.dart)
│   ├── bloc/ (category_bloc, provider_search_bloc, request_creation_bloc)
│   └── presentation/
│       ├── category_list_view.dart
│       ├── provider_detail_screen.dart
│       ├── create_request_screen.dart
│       └── customer_request_history_screen.dart
└── provider/
├── data/ (provider_repository.dart)
├── bloc/ (provider_job_bloc)
└── presentation/
├── provider_dashboard.dart
├── incoming_request_card.dart
└── active_job_screen.dart

# Xirfadle Mobile App Specifications (Flutter)

## System Role & Objective
You are a Principal Flutter & Cross-Platform Mobile Engineer. Build a production-ready, highly modular Flutter application for **Xirfadle**, a local service-matching platform. The single Flutter codebase must support two distinct user modes/views: **Customer Mode** and **Skilled Person (Provider) Mode**, driving a multi-role experience powered by ASP.NET Core Web API backend endpoints.


## Technical Stack Guidelines
* **Framework:** Flutter (latest stable release)
* **Language:** Dart
* **State Management & Architecture:** Feature-First Architecture using **flutter_bloc** (or **Riverpod**) for reactive state handling.
* **Networking:** `dio` for HTTP requests with custom interceptors for JWT injection and token refresh.
* **Local Storage:** `flutter_secure_storage` for token persistence and `shared_preferences` for app preferences.
* **Location & Maps:** `geolocator` and `google_maps_flutter` (or `flutter_map`) for location picking and distance display.


## App Modes & Workflow Specifications

### 1. Unified Authentication & Role Selection
* **Splash & Auth Flow:** Phone number registration/login via API (`POST /api/v1/auth/login`).
* **Role Switcher / Navigation Guard:** Upon authentication, inspect `Role` claim from the JWT:
  * If `Customer` $\rightarrow$ route directly to **Customer View Dashboard**.
  * If `Provider` $\rightarrow$ route directly to **Skilled Person Dashboard**.
  * If dual role permitted, provide a profile toggle to switch operational modes.


### 2. Customer Mode Workflow

#### **A. Service Discovery & Browsing (`/customer/home`)**
* **Category Grid:** Visual categories (Plumbing, Electrical, Tutoring) retrieved from `GET /api/v1/customer/categories`.
* **Provider Search & Profiles:** 
  * List available providers sorted by rating and proximity (`GET /api/v1/customer/providers`).
  * Provider detail screen featuring bio, average star rating, total job reviews, and specialty tags (`GET /api/v1/customer/providers/{id}`).

#### **B. Service Request Submission (`/customer/create-request`)**
* **Request Creation Form:**
  * Category selector.
  * Description input (issue details, timing preference).
  * Address picker (Map pin or manually entered address).
* **Submission Action:** Triggers `POST /api/v1/customer/requests` with status initialized to `PendingAdminReview`.
* **Status Confirmation Screen:** Informs the customer that an admin will call them off-platform to confirm job details and pricing.

#### **C. My Requests & Live Status Tracker (`/customer/my-requests`)**
* List of submitted jobs with real-time status badges:
  * `PendingAdminReview` $\rightarrow$ "Admin Reviewing" (Yellow)
  * `ConfirmedByAdmin` / `Assigned` $\rightarrow$ "Matching Provider" (Blue)
  * `AcceptedByProvider` $\rightarrow$ "Provider Assigned & Confirmed" (Green)
  * `Completed` $\rightarrow$ "Completed — Tap to Rate"
* **Rating & Review Modal:** Triggers `POST /api/v1/customer/reviews` upon job completion.


### 3. Skilled Person (Provider) Mode Workflow

#### **A. Provider Dashboard & Duty Toggle (`/provider/home`)**
* **Availability Toggle:** Switch `IsAvailable` online/offline state to notify admins of willingness to receive dispatches.
* **Active Assigned Tasks Banner:** Prominent notification card showing newly dispatched tasks awaiting provider response.

#### **B. Dispatched Task Accept / Reject Flow (`/provider/requests`)**
* **Incoming Job Request Card:** Displays customer address, service category, problem description, and `AgreedPrice` set by the admin.
* **Action Controls:**
  * **Accept Button:** Calls `PATCH /api/v1/provider/requests/{id}/respond` with `status: AcceptedByProvider`. Transitions job to active state.
  * **Reject Button:** Calls `PATCH /api/v1/provider/requests/{id}/respond` with `status: RejectedByProvider` + reason prompt. Immediately alerts admin portal for re-dispatch.

#### **C. Job Completion Flow (`/provider/active-job`)**
* Step-by-step job tracker (`Accepted` $\rightarrow$ `In Progress` $\rightarrow$ `Completed`).
* **Mark Complete Action:** Calls `PATCH /api/v1/provider/requests/{id}/complete` to finish task and trigger customer review availability.


## Architecture & Directory Layout (Feature-First)

lib/
├── app/
│   ├── config/ (routes, themes, constants)
│   └── main.dart
├── core/
│   ├── network/ (dio_client.dart, api_interceptors.dart)
│   ├── storage/ (secure_storage_service.dart)
│   └── widgets/ (custom_buttons, loading_indicators, status_badges)
└── features/
├── auth/
│   ├── data/ (auth_repository.dart)
│   ├── bloc/ (auth_bloc.dart, auth_event.dart, auth_state.dart)
│   └── presentation/ (login_screen.dart, register_screen.dart)
├── customer/
│   ├── data/ (customer_repository.dart)
│   ├── bloc/ (category_bloc, provider_search_bloc, request_creation_bloc)
│   └── presentation/
│       ├── category_list_view.dart
│       ├── provider_detail_screen.dart
│       ├── create_request_screen.dart
│       └── customer_request_history_screen.dart
└── provider/
├── data/ (provider_repository.dart)
├── bloc/ (provider_job_bloc)
└── presentation/
├── provider_dashboard.dart
├── incoming_request_card.dart
└── active_job_screen.dart



## Deliverables Requested

1. **Complete Modular Project Tree:** Clean Dart file organization following Feature-First pattern.
2. **Network Layer:** Pre-configured `Dio` HTTP client with JWT Authorization header injection interceptor and base URL configuration.
3. **Auth & State Routing Logic:** BLoC / Provider logic managing login state and routing the app between Customer and Provider interfaces based on user role claims.
4. **Key Feature Screen Implementations:**
   * Customer Request Creation Form with state handling.
   * Customer Request History view with dynamic status badges matching the backend state machine.
   * Provider Dispatch Screen containing Accept/Reject action buttons and logic.


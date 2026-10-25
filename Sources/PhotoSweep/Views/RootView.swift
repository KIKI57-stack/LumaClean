import Photos
import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            content

            if let toast = model.toast {
                VStack {
                    Spacer()
                    ToastView(text: toast)
                        .padding(.bottom, 26)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .task {
            if model.authStatus == .notDetermined {
                await model.requestAccess()
            } else if model.isAuthorized {
                model.refreshCounts()
            }
        }
        .onChange(of: model.toast) { value in
            guard value != nil else { return }
            Task {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                model.toast = nil
            }
        }
        .alert(
            "出错了",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.isAuthorized {
            PermissionView(status: model.authStatus) {
                if model.authStatus == .notDetermined {
                    Task { await model.requestAccess() }
                } else {
                    openSystemSettings()
                }
            }
        } else if model.isScanning {
            ScanningView()
        } else if model.result != nil {
            NavigationStack {
                OverviewView()
            }
        } else {
            NavigationStack {
                HomeView()
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

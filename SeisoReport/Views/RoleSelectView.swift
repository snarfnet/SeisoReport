import SwiftUI

struct RoleSelectView: View {
    @Environment(DataStore.self) private var store
    @State private var showPasswordPrompt = false
    @State private var passwordInput = ""
    @State private var passwordError = false
    @State private var showRecovery = false
    @State private var recoveryInput = ""
    @State private var recoveryError = false
    @State private var showResetSuccess = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "building.2.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("清掃報告書")
                .font(.system(size: 32, weight: .black, design: .rounded))

            Text("役割を選択してください")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                Button {
                    passwordInput = ""
                    passwordError = false
                    showPasswordPrompt = true
                } label: {
                    Label("管理者", systemImage: "person.badge.key.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button {
                    store.setRole(false)
                } label: {
                    Label("作業員", systemImage: "person.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(.green, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .alert("管理者パスワード", isPresented: $showPasswordPrompt) {
            SecureField("パスワード", text: $passwordInput)
            Button("ログイン") {
                if passwordInput == store.adminPassword {
                    store.setRole(true)
                } else {
                    passwordError = true
                }
            }
            Button("パスワードを忘れた") {
                recoveryInput = ""
                recoveryError = false
                showRecovery = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("管理者パスワードを入力してください")
        }
        .alert("パスワードが違います", isPresented: $passwordError) {
            Button("再試行") {
                passwordInput = ""
                showPasswordPrompt = true
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("パスワードリセット", isPresented: $showRecovery) {
            TextField("リカバリーコード（6桁）", text: $recoveryInput)
                .keyboardType(.numberPad)
            Button("リセット") {
                if recoveryInput == store.recoveryCode {
                    store.adminPassword = "0000"
                    store.recoveryCode = String(format: "%06d", Int.random(in: 100000...999999))
                    store.save()
                    showResetSuccess = true
                } else {
                    recoveryError = true
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("初回設定時に表示されたリカバリーコードを入力してください")
        }
        .alert("リカバリーコードが違います", isPresented: $recoveryError) {
            Button("OK") {}
        }
        .alert("パスワードをリセットしました", isPresented: $showResetSuccess) {
            Button("OK") {
                passwordInput = ""
                showPasswordPrompt = true
            }
        } message: {
            Text("パスワードが「0000」にリセットされました。\n\n新しいリカバリーコード: \(store.recoveryCode)\n\nこのコードを必ず控えてください。")
        }
    }
}

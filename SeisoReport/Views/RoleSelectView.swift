import SwiftUI

struct RoleSelectView: View {
    @Environment(DataStore.self) private var store
    @State private var showPinPrompt = false
    @State private var pinInput = ""
    @State private var pinError = false

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
                    pinInput = ""
                    pinError = false
                    showPinPrompt = true
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
        .alert("管理者PIN", isPresented: $showPinPrompt) {
            SecureField("PINを入力", text: $pinInput)
                .keyboardType(.numberPad)
            Button("ログイン") {
                if pinInput == store.adminPin {
                    store.setRole(true)
                } else {
                    pinError = true
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("管理者PINを入力してください")
        }
        .alert("PINが違います", isPresented: $pinError) {
            Button("OK") {}
        }
    }
}

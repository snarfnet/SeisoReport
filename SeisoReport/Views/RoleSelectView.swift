import SwiftUI

struct RoleSelectView: View {
    @Environment(DataStore.self) private var store

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
                    store.setRole(true)
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
    }
}

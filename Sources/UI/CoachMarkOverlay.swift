import SwiftUI

struct CoachMarkOverlay: View {
    @State private var step: Int = 0
    let onComplete: () -> Void

    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Dimming background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { advance() }

            VStack {
                switch step {
                case 0: dragAreaCoach
                case 1: buttonCoach
                default: settingsCoach
                }
            }
            .animation(.easeInOut(duration: 0.2), value: step)

            // Skip button
            VStack {
                HStack {
                    Spacer()
                    Button("건너뛰기") {
                        onComplete()
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                Spacer()
            }
        }
    }

    // MARK: - Steps

    private var dragAreaCoach: some View {
        VStack {
            Spacer().frame(height: 80)
            coachCard(
                title: "파일을 여기로 드래그",
                description: "파일을 끌어다 놓거나 ⌘V로 붙여넣기",
                stepNumber: 1
            )
            Spacer()
        }
    }

    private var buttonCoach: some View {
        VStack {
            Spacer()
            coachCard(
                title: "AI 자동 분류",
                description: "파일 추가 후 버튼을 누르면\nAI가 PARA 구조로 분류합니다",
                stepNumber: 2
            )
            Spacer().frame(height: 140)
        }
    }

    private var settingsCoach: some View {
        VStack {
            Spacer()
            coachCard(
                title: "설정",
                description: "API 키와 폴더 경로를\n언제든 변경할 수 있습니다",
                stepNumber: 3
            )
            Spacer().frame(height: 40)
        }
    }

    // MARK: - Card

    private func coachCard(title: String, description: String, stepNumber: Int) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Text("\(stepNumber)/\(totalSteps)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))

                Button(action: advance) {
                    Text(stepNumber < totalSteps ? "다음" : "완료")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
        .padding(.horizontal, 48)
    }

    private func advance() {
        if step < totalSteps - 1 {
            step += 1
        } else {
            onComplete()
        }
    }
}

import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
                .frame(width: 240)
                .background(SidebarBackground())

            Divider()

            VStack(spacing: 0) {
                StatusBanner(viewModel: viewModel)
                    .padding(.vertical, 14)

                BoardView(viewModel: viewModel)
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.12, green: 0.13, blue: 0.16))
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .animation(.easeInOut(duration: 0.2), value: viewModel.status)
    }
}

// MARK: - Status Banner

struct StatusBanner: View {
    @ObservedObject var viewModel: GameViewModel

    private var label: String {
        switch viewModel.status {
        case .playing:
            if viewModel.isAIThinking { return "AI is thinking..." }
            let who = viewModel.currentPlayer.displayName
            let suffix = (viewModel.gameMode == .pvAI && viewModel.currentPlayer == .white) ? " (AI)" : ""
            return "\(who)'s Turn\(suffix)"
        case .won(let p):
            return "\(p.displayName) Wins!"
        case .draw:
            return "Draw — Well Played!"
        }
    }

    private var labelColor: Color {
        switch viewModel.status {
        case .playing:    return .primary
        case .won(.black): return Color(white: 0.9)
        case .won(.white): return Color(red: 1, green: 0.85, blue: 0.4)
        case .draw:        return .secondary
        }
    }

    private var bgColor: Color {
        switch viewModel.status {
        case .playing:    return Color(.windowBackgroundColor).opacity(0.85)
        case .won(.black): return Color(red: 0.18, green: 0.18, blue: 0.2).opacity(0.95)
        case .won(.white): return Color(red: 0.22, green: 0.20, blue: 0.10).opacity(0.95)
        case .draw:        return Color(.windowBackgroundColor).opacity(0.85)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if case .playing = viewModel.status, viewModel.isAIThinking {
                ProgressView()
                    .scaleEffect(0.65)
                    .progressViewStyle(.circular)
            }
            if case .won(_) = viewModel.status {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 14))
                    .transition(.scale.combined(with: .opacity))
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(labelColor)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(bgColor)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        )
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            appHeader
            Divider().padding(.horizontal, 16).padding(.vertical, 4)
            gameModeSection
            Divider().padding(.horizontal, 16).padding(.vertical, 4)
            playersSection
            Spacer()
            controlsSection
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: Header

    private var appHeader: some View {
        VStack(spacing: 3) {
            Text("CONNECT 5")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .tracking(2)
            Text("五子棋  ·  Gomoku")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 14)
    }

    // MARK: Mode

    private var gameModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("GAME MODE")
            Picker("", selection: $viewModel.gameMode) {
                ForEach(GameMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .disabled(!viewModel.moveHistory.isEmpty)

            if viewModel.gameMode == .pvAI {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text("You play Black, AI plays White")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: Players

    private var playersSection: some View {
        VStack(spacing: 10) {
            PlayerCard(
                player: .black,
                score: viewModel.blackScore,
                isActive: viewModel.currentPlayer == .black && !viewModel.status.isOver,
                isWinner: viewModel.status == .won(.black),
                label: viewModel.gameMode == .pvAI ? "You" : "Player 1"
            )

            HStack {
                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 0.5)
                Text("VS").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 0.5)
            }
            .padding(.horizontal, 16)

            PlayerCard(
                player: .white,
                score: viewModel.whiteScore,
                isActive: viewModel.currentPlayer == .white && !viewModel.status.isOver,
                isWinner: viewModel.status == .won(.white),
                label: viewModel.gameMode == .pvAI ? "AI" : "Player 2",
                showAIBadge: viewModel.gameMode == .pvAI
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: Controls

    private var controlsSection: some View {
        VStack(spacing: 8) {
            if viewModel.status.isOver {
                Button(action: viewModel.newGame) {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)
            } else {
                Button(action: viewModel.newGame) {
                    Label("New Game", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)

                Button(action: viewModel.undoLastMove) {
                    Label("Undo Move", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.moveHistory.isEmpty || viewModel.isAIThinking)
                .keyboardShortcut("z", modifiers: .command)
            }

            Divider().padding(.vertical, 2)

            HStack {
                Button(action: viewModel.resetScores) {
                    Text("Reset Scores")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                if !viewModel.moveHistory.isEmpty {
                    Text("Move \(viewModel.moveHistory.count)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(1.5)
            .padding(.horizontal, 18)
    }
}

// MARK: - Player Card

struct PlayerCard: View {
    let player: Player
    let score: Int
    let isActive: Bool
    let isWinner: Bool
    var label: String = ""
    var showAIBadge: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Stone icon
            ZStack {
                Circle()
                    .fill(stoneGrad)
                    .frame(width: 34, height: 34)
                    .shadow(
                        color: player == .black ? .black.opacity(0.5) : .black.opacity(0.2),
                        radius: 3, x: 1, y: 2
                    )
                    .overlay(
                        Circle().strokeBorder(Color.gray.opacity(0.35), lineWidth: 0.75)
                    )

                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                        .shadow(color: .orange, radius: 3)
                        .offset(y: -20)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(label.isEmpty ? player.displayName : label)
                        .font(.system(size: 13, weight: .semibold))

                    if showAIBadge {
                        Text("CPU")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.blue.opacity(0.8)))
                    }
                }

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < score % 3 ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                    Text("  \(score) \(score == 1 ? "win" : "wins")")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Active indicator
            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.green.opacity(0.35), lineWidth: 4))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive
                      ? Color.accentColor.opacity(0.1)
                      : Color(.controlBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isWinner ? Color.yellow.opacity(0.6) :
                            isActive ? Color.accentColor.opacity(0.4) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.spring(response: 0.3), value: isWinner)
    }

    var stoneGrad: RadialGradient {
        player == .black
        ? RadialGradient(colors: [Color(white: 0.38), Color(white: 0.04)],
                         center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 20)
        : RadialGradient(colors: [Color(white: 1.0), Color(white: 0.72)],
                         center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: 20)
    }
}

// MARK: - Sidebar Background

struct SidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Preview

#Preview {
    ContentView()
}

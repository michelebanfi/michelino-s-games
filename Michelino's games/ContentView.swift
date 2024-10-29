import SwiftUI

struct ContentView: View {
    @State private var isGameStarted = false
    
    var body: some View {
        if isGameStarted {
            GameBoard()
        } else {
            MainMenu(isGameStarted: $isGameStarted)
        }
    }
}

struct MainMenu: View {
    @Binding var isGameStarted: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Queen's Puzzle")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                Text("Rules:")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("• Your goal is to have exactly one 👑 in each row, column, and color region.")
                Text("• Tap once to place X and tap twice for 👑")
                Text("• Use X to mark where 👑 cannot be placed")
                Text("• Two 👑 cannot touch each other, not even diagonally")
            }
            .padding()
            .multilineTextAlignment(.leading)
            
            Button(action: {
                isGameStarted = true
            }) {
                Text("Start Game")
                    .font(.title3)
                    .padding()
                    .frame(width: 200)
                    .background(Color(UIColor.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
        }
    }
}


extension Color {
    static let coral = Color(red: 1.0, green: 0.5, blue: 0.4)
    static let peach = Color(red: 1.0, green: 0.8, blue: 0.6)
}


#Preview {
    ContentView()
}

struct BoardPosition: Hashable {
    let row: Int
    let col: Int
}

struct GameBoard: View {
    let boardSize = 8
        @State private var board: [[CellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        @State private var illegalMoves: Set<BoardPosition> = []
        @State private var showAlert = false
        @State private var isSuccess = false
        @State private var colorRegions: [[Color]] = []
    
    // Initialize with a generated puzzle
    init() {
        _colorRegions = State(initialValue: PuzzleGenerator.generateColorRegions())
    }
    
    enum CellState {
        case empty
        case marked
        case queen
    }
    
    // CellView definition
    struct CellView: View {
        let state: CellState
        let backgroundColor: Color
        let isIllegal: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    Rectangle()
                        .fill(backgroundColor.opacity(0.3))
                        .frame(width: 40, height: 40)
                    
                    if state == .marked {
                        Image(systemName: "multiply")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    } else if state == .queen {
                        Text("👑")
                            .font(.system(size: 24))
                    }
                    
                    if isIllegal {
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .dash(lengths: [5])
                            )
                    }
                }
            }
            .frame(width: 40, height: 40)
            .background(Color(UIColor.systemGray6))
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 1) {
                ForEach(0..<boardSize, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<boardSize, id: \.self) { col in
                            CellView(
                                state: board[row][col],
                                backgroundColor: colorRegions[row][col],
                                isIllegal: illegalMoves.contains(BoardPosition(row: row, col: col)),
                                action: { toggleCell(row: row, col: col) }
                            )
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGray5))
            .padding(.horizontal)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: {
                    checkSolution()
                }) {
                    Text("Check Solution")
                        .font(.title3)
                        .padding()
                        .frame(width: 160)
                        .background(Color(UIColor.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                
                Button(action: {
                    newPuzzle()
                }) {
                    Text("New Puzzle")
                        .font(.title3)
                        .padding()
                        .frame(width: 160)
                        .background(Color(UIColor.systemGreen))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(isSuccess ? "Congratulations! 🎉" : "Not Quite Right"),
                message: Text(isSuccess ?
                    "You've solved the puzzle correctly!" :
                    "Keep trying! Remember:\n• One queen per row\n• One queen per column\n• One queen per color region\n• Queens can't touch, even diagonally"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func newPuzzle() {
        // Reset the board
        board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        illegalMoves.removeAll()
        // Generate new color regions
        colorRegions = PuzzleGenerator.generateColorRegions()
    }
    
    private func checkSolution() {
        isSuccess = validateSolution()
        showAlert = true
    }
    
    private func toggleCell(row: Int, col: Int) {
        switch board[row][col] {
        case .empty:
            board[row][col] = .marked
            // Clear illegal moves when placing X
            illegalMoves.remove(BoardPosition(row: row, col: col))
        case .marked:
            board[row][col] = .queen
            // Check queen placement immediately after placing
            validateQueenPlacement(row: row, col: col)
        case .queen:
            board[row][col] = .empty
            // Clear illegal moves when removing queen
            illegalMoves.remove(BoardPosition(row: row, col: col))
            // Revalidate remaining queens
            revalidateAllQueens()
        }
    }
    
    private func validateQueenPlacement(row: Int, col: Int) {
        let currentQueen = BoardPosition(row: row, col: col)
        
        // Check conflicts with other queens
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                if board[r][c] == .queen {
                    let otherQueen = BoardPosition(row: r, col: c)
                    if otherQueen != currentQueen {
                        if isConflict(queen1: currentQueen, queen2: otherQueen) {
                            illegalMoves.insert(currentQueen)
                            illegalMoves.insert(otherQueen)
                        }
                        
                        // Check same color region
                        if colorRegions[r][c] == colorRegions[row][col] {
                            illegalMoves.insert(currentQueen)
                            illegalMoves.insert(otherQueen)
                        }
                    }
                }
            }
        }
    }
    
    private func revalidateAllQueens() {
        illegalMoves.removeAll()
        
        // Get all queen positions
        var queenPositions: [BoardPosition] = []
        for r in 0..<boardSize {
            for c in 0..<boardSize {
                if board[r][c] == .queen {
                    queenPositions.append(BoardPosition(row: r, col: c))
                }
            }
        }
        
        // Check each queen against every other queen
        for (index, queen1) in queenPositions.enumerated() {
            for queen2 in queenPositions[(index + 1)...] {
                if isConflict(queen1: queen1, queen2: queen2) {
                    illegalMoves.insert(queen1)
                    illegalMoves.insert(queen2)
                }
                
                // Check same color region
                if colorRegions[queen1.row][queen1.col] == colorRegions[queen2.row][queen2.col] {
                    illegalMoves.insert(queen1)
                    illegalMoves.insert(queen2)
                }
            }
        }
    }
    
    private func isConflict(queen1: BoardPosition, queen2: BoardPosition) -> Bool {
        // Same row or column
        if queen1.row == queen2.row || queen1.col == queen2.col {
            return true
        }
        
        let rowDiff = abs(queen1.row - queen2.row)
        let colDiff = abs(queen1.col - queen2.col)
        
        // Check if queens are in adjacent cells (including diagonally)
        if rowDiff <= 1 && colDiff <= 1 {
            return true
        }
        
        return false
    }
    
    private func validateSolution() -> Bool {
        var rowCounts = Array(repeating: 0, count: boardSize)
        var colCounts = Array(repeating: 0, count: boardSize)
        var regionCounts: [Color: Int] = [:]
        
        // Count queens in each row, column, and color region
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if board[row][col] == .queen {
                    rowCounts[row] += 1
                    colCounts[col] += 1
                    regionCounts[colorRegions[row][col], default: 0] += 1
                }
            }
        }
        
        // Verify one queen per row and column
        guard rowCounts.allSatisfy({ $0 == 1 }) && colCounts.allSatisfy({ $0 == 1 }) else {
            return false
        }
        
        // Verify one queen per color region
        guard regionCounts.values.allSatisfy({ $0 == 1 }) else {
            return false
        }
        
        // Verify no illegal placements
        return illegalMoves.isEmpty
    }
}

// Extension to add dashed border support
extension View {
    func dash(lengths: [CGFloat] = [5]) -> some View {
        self.modifier(DashBorder(lengths: lengths))
    }
}

struct DashBorder: ViewModifier {
    let lengths: [CGFloat]
    
    func body(content: Content) -> some View {
        content
            .mask(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: lengths))
            )
    }
}

enum PuzzleGenerator {
    static func generateColorRegions() -> [[Color]] {
        // Define a set of colors to use
        let colors: [Color] = [.purple, .yellow, .blue, .green, .gray,
                             .coral, .brown, .peach]
        
        var regions = Array(repeating: Array(repeating: Color.clear, count: 8), count: 8)
        var remainingCells = Set<BoardPosition>()
        
        // Initialize all cells as available
        for row in 0..<8 {
            for col in 0..<8 {
                remainingCells.insert(BoardPosition(row: row, col: col))
            }
        }
        
        // Assign regions
        for color in colors {
            let regionSize = remainingCells.count / (colors.count)
            var cellsForRegion = regionSize
            
            while cellsForRegion > 0 && !remainingCells.isEmpty {
                // Pick a random starting cell
                guard let start = remainingCells.randomElement() else { break }
                remainingCells.remove(start)
                regions[start.row][start.col] = color
                
                // Try to grow region by adding adjacent cells
                var adjacentCells = getAdjacentCells(start, remainingCells: remainingCells)
                while cellsForRegion > 1 && !adjacentCells.isEmpty {
                    guard let next = adjacentCells.randomElement() else { break }
                    adjacentCells.remove(next)
                    remainingCells.remove(next)
                    regions[next.row][next.col] = color
                    cellsForRegion -= 1
                    
                    // Update adjacent cells
                    adjacentCells.formUnion(getAdjacentCells(next, remainingCells: remainingCells))
                }
                cellsForRegion -= 1
            }
        }
        
        // Fill any remaining cells with random colors
        for cell in remainingCells {
            regions[cell.row][cell.col] = colors.randomElement() ?? .gray
        }
        
        return regions
    }
    
    private static func getAdjacentCells(_ pos: BoardPosition, remainingCells: Set<BoardPosition>) -> Set<BoardPosition> {
        var adjacent = Set<BoardPosition>()
        let directions = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        
        for (dx, dy) in directions {
            let newRow = pos.row + dx
            let newCol = pos.col + dy
            let newPos = BoardPosition(row: newRow, col: newCol)
            
            if newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8 && remainingCells.contains(newPos) {
                adjacent.insert(newPos)
            }
        }
        
        return adjacent
    }
}

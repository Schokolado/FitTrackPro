import SwiftUI
import UniformTypeIdentifiers

// MARK: - Jiggle Modifier

struct JiggleModifier: ViewModifier {
    var isEnabled: Bool
    
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isEnabled && isAnimating ? 1.0 : (isEnabled ? -1.0 : 0)))
            .onAppear {
                if isEnabled {
                    startJiggle()
                }
            }
            .onChange(of: isEnabled) { enabled in
                if enabled {
                    startJiggle()
                } else {
                    withAnimation(.default) {
                        isAnimating = false
                    }
                }
            }
    }
    
    private func startJiggle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.1)) {
            withAnimation(Animation.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

extension View {
    func jiggle(isEnabled: Bool) -> some View {
        self.modifier(JiggleModifier(isEnabled: isEnabled))
    }
}

// MARK: - Drop Delegate

struct DashboardDropDelegate: DropDelegate {
    let item: DashboardCardType
    let layoutManager: DashboardLayoutManager
    
    func dropEntered(info: DropInfo) {
        layoutManager.hoveredArea = item.rawValue
        if let current = layoutManager.draggedItem, current != item {
            withAnimation(.default) {
                layoutManager.moveCard(from: current, to: item)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .copy)
    }
    
    func dropExited(info: DropInfo) {
    }
    
    func performDrop(info: DropInfo) -> Bool {
        if info.hasItemsConforming(to: [UTType.plainText.identifier]) {
            layoutManager.save()
            return true
        }
        return false
    }
}

// MARK: - Dashboard Reset Drop Delegate
struct DashboardResetDropDelegate: DropDelegate {
    let layoutManager: DashboardLayoutManager
    
    func dropEntered(info: DropInfo) {
        layoutManager.hoveredArea = "background"
    }
    
    func dropExited(info: DropInfo) {
    }
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
}

class TrackingItemProvider: NSItemProvider {
    var deinitAction: (() -> Void)?
    deinit {
        let action = self.deinitAction
        DispatchQueue.main.async {
            action?()
        }
    }
}

// MARK: - Dashboard Grid Layout

struct DashboardCardSizeKey: LayoutValueKey {
    static let defaultValue: DashboardCardSize = .small
}

extension View {
    func dashboardCardSize(_ size: DashboardCardSize) -> some View {
        self.layoutValue(key: DashboardCardSizeKey.self, value: size)
    }
}

struct DashboardGridLayout: Layout {
    var spacing: CGFloat = 16
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let boundsWidth = proposal.width ?? 350
        let smallWidth = (boundsWidth - spacing) / 2
        
        var currentY: CGFloat = 0
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let sizeType = subview[DashboardCardSizeKey.self]
            let itemWidth = sizeType == .large ? boundsWidth : smallWidth
            
            // Wrap if it doesn't fit
            if currentX + itemWidth > boundsWidth + 1 {
                currentY += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            
            let itemSize = subview.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            let safeHeight = min(itemSize.height, 1000)
            rowHeight = max(rowHeight, safeHeight)
            
            currentX += itemWidth + spacing
        }
        
        return CGSize(width: boundsWidth, height: currentY + rowHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let boundsWidth = bounds.width
        let smallWidth = (boundsWidth - spacing) / 2
        
        var currentY: CGFloat = bounds.minY
        var currentX: CGFloat = bounds.minX
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let sizeType = subview[DashboardCardSizeKey.self]
            let itemWidth = sizeType == .large ? boundsWidth : smallWidth
            
            if currentX + itemWidth > bounds.maxX + 1 {
                currentY += rowHeight + spacing
                currentX = bounds.minX
                rowHeight = 0
            }
            
            let pSize = ProposedViewSize(width: itemWidth, height: nil)
            let itemSize = subview.sizeThatFits(pSize)
            
            subview.place(at: CGPoint(x: currentX, y: currentY), anchor: .topLeading, proposal: pSize)
            
            rowHeight = max(rowHeight, itemSize.height)
            currentX += itemWidth + spacing
        }
    }
}

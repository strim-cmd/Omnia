import SwiftUI

public enum OmniaTheme {
    public enum Colors {
        public static let background = Color(red: 0.02, green: 0.02, blue: 0.02)
        public static let surface = Color(red: 0.1, green: 0.1, blue: 0.12)
        public static let surfaceElevated = Color(red: 0.15, green: 0.15, blue: 0.17)
        public static let accentPurple = Color(red: 0.54, green: 0.17, blue: 0.89)
        public static let accentCyan = Color(red: 0.0, green: 0.8, blue: 0.82)
        public static let textPrimary = Color.white
        public static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)
        public static let border = Color(red: 0.2, green: 0.2, blue: 0.25)
    }
    
    public enum Radii {
        public static let container: CGFloat = 20
        public static let bubble: CGFloat = 16
        public static let composer: CGFloat = 16
        public static let button: CGFloat = 12
    }
    
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }
    
    public enum Shadows {
        public static let surface = Color.black.opacity(0.15)
        public static let bubble = Color.black.opacity(0.1)
    }
}

import Foundation

/// Three-dimensional vector for position and velocity
public struct Vector3D {
    public let x: Double
    public let y: Double
    public let z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Magnitude of the vector
    public var magnitude: Double {
        return sqrt(x * x + y * y + z * z)
    }

    /// Dot product with another vector
    public func dot(_ other: Vector3D) -> Double {
        return x * other.x + y * other.y + z * other.z
    }

    /// Cross product with another vector
    public func cross(_ other: Vector3D) -> Vector3D {
        return Vector3D(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    /// Add two vectors
    public static func + (lhs: Vector3D, rhs: Vector3D) -> Vector3D {
        return Vector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    /// Subtract two vectors
    public static func - (lhs: Vector3D, rhs: Vector3D) -> Vector3D {
        return Vector3D(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    /// Multiply vector by scalar
    public static func * (lhs: Vector3D, rhs: Double) -> Vector3D {
        return Vector3D(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    /// Multiply scalar by vector
    public static func * (lhs: Double, rhs: Vector3D) -> Vector3D {
        return Vector3D(x: rhs.x * lhs, y: rhs.y * lhs, z: rhs.z * lhs)
    }

    /// Divide vector by scalar
    public static func / (lhs: Vector3D, rhs: Double) -> Vector3D {
        return Vector3D(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

// MARK: - Equatable
extension Vector3D: Equatable {
    public static func == (lhs: Vector3D, rhs: Vector3D) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
}

// MARK: - CustomStringConvertible
extension Vector3D: CustomStringConvertible {
    public var description: String {
        return "(\(x), \(y), \(z))"
    }
}

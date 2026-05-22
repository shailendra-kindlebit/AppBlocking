//
//  Animatable.swift
//  Vigilant
//
//  Created by KBS on 5/14/26.
//

import SwiftUI
public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: AnimatableData {get set}
}

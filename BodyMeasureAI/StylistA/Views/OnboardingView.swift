//
//  OnboardingView.swift
//  BodyMeasureAI
//
//  Simple input screen before scan: height and gender. Stores inputs in ViewModel.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var heightCm: Double
    @Binding var gender: Gender
    @Binding var name: String
    @Binding var age: Int
    var onStartScan: () -> Void
    var onStartGarmentScan: () -> Void
    var onOpenHistory: () -> Void

    @State private var heightText: String = ""
    @State private var ageText: String = ""
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            VStack(spacing: 0) {

                // Wordmark top left + history entry top right
                HStack {
                    Text("STYLISTA")
                        .font(SFont.label(13))
                        .tracking(6)
                        .foregroundStyle(Color("sPrimary"))
                    Spacer()
                    Button(action: onOpenHistory) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .medium))
                            Text("HISTORY")
                                .font(SFont.label(11))
                                .tracking(2)
                        }
                        .foregroundStyle(Color("sSecondary"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color("sSurface"))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, 56)

                Spacer()

                // Hero text
                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    Text("Your body.\nYour style.")
                        .font(SFont.display(42, weight: .light))
                        .foregroundStyle(Color("sPrimary"))
                        .lineSpacing(4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.1),
                                   value: appeared)

                    Text("Scan your body or a garment\nanytime. Dress perfectly.")
                        .font(SFont.body(16))
                        .foregroundStyle(Color("sSecondary"))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.6).delay(0.25),
                                   value: appeared)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SSpacing.lg)

                Spacer()

                // Input card
                VStack(spacing: SSpacing.lg) {

                    // Name
                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        Text("NAME")
                            .font(SFont.label(11))
                            .tracking(2)
                            .foregroundStyle(Color("sTertiary"))

                        TextField("Who's being scanned?", text: $name)
                            .font(SFont.display(22, weight: .light))
                            .foregroundStyle(Color("sPrimary"))
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled(true)
                            .submitLabel(.next)

                        Rectangle()
                            .fill(Color("sBorder"))
                            .frame(height: 1)
                    }

                    // Age + Height (side by side, both numeric)
                    HStack(spacing: SSpacing.lg) {
                        VStack(alignment: .leading, spacing: SSpacing.xs) {
                            Text("AGE")
                                .font(SFont.label(11))
                                .tracking(2)
                                .foregroundStyle(Color("sTertiary"))

                            HStack {
                                TextField("30", text: $ageText)
                                    .font(SFont.display(32, weight: .light))
                                    .foregroundStyle(Color("sPrimary"))
                                    .keyboardType(.numberPad)
                                    .onChange(of: ageText) { _, v in
                                        if let val = Int(v), val >= 1, val <= 120 {
                                            age = val
                                        } else if v.isEmpty {
                                            age = 0
                                        }
                                    }
                                    .onAppear {
                                        if age > 0 { ageText = String(age) }
                                    }

                                Text("yrs")
                                    .font(SFont.body(16))
                                    .foregroundStyle(Color("sTertiary"))
                            }

                            Rectangle()
                                .fill(Color("sBorder"))
                                .frame(height: 1)
                        }

                        VStack(alignment: .leading, spacing: SSpacing.xs) {
                            Text("HEIGHT")
                                .font(SFont.label(11))
                                .tracking(2)
                                .foregroundStyle(Color("sTertiary"))

                            HStack {
                                TextField("170", text: $heightText)
                                    .font(SFont.display(32, weight: .light))
                                    .foregroundStyle(Color("sPrimary"))
                                    .keyboardType(.decimalPad)
                                    .onChange(of: heightText) { _, v in
                                        if let val = Double(v), val > 0 { heightCm = val }
                                    }
                                    .onAppear {
                                        if heightCm > 0 {
                                            heightText = String(Int(heightCm))
                                        }
                                    }

                                Text("cm")
                                    .font(SFont.body(16))
                                    .foregroundStyle(Color("sTertiary"))
                            }

                            Rectangle()
                                .fill(Color("sBorder"))
                                .frame(height: 1)
                        }
                    }

                    // Gender
                    VStack(alignment: .leading, spacing: SSpacing.sm) {
                        Text("GENDER")
                            .font(SFont.label(11))
                            .tracking(2)
                            .foregroundStyle(Color("sTertiary"))

                        Picker("", selection: $gender) {
                            ForEach(Gender.allCases, id: \.self) { g in
                                Text(g.displayName).tag(g)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.black)
                    }
                }
                .padding(SSpacing.lg)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                .softShadow()
                .padding(.horizontal, SSpacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)

                Spacer().frame(height: SSpacing.lg)

                // Primary / secondary scan actions. Either path can be taken first.
                VStack(spacing: SSpacing.sm) {
                    scanActionTile(
                        title: "Scan Body",
                        subtitle: "Full-body measurements",
                        systemImage: "figure.stand",
                        style: .primary
                    ) {
                        if let v = Double(heightText), v > 0 { heightCm = v }
                        dismissKeyboard()
                        onStartScan()
                    }

                    scanActionTile(
                        title: "Scan Garment",
                        subtitle: "Identify a piece you own",
                        systemImage: "tshirt",
                        style: .secondary
                    ) {
                        dismissKeyboard()
                        onStartGarmentScan()
                    }
                }
                .padding(.horizontal, SSpacing.lg)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.55), value: appeared)

                Spacer().frame(height: SSpacing.xxl)
            }
        }
        .onAppear { appeared = true }
    }

    private enum TileStyle { case primary, secondary }

    @ViewBuilder
    private func scanActionTile(
        title: String,
        subtitle: String,
        systemImage: String,
        style: TileStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .light))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SFont.label(15))
                        .tracking(1)
                    Text(subtitle)
                        .font(SFont.body(12))
                        .opacity(0.75)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(style == .primary ? Color("sBackground") : Color("sPrimary"))
            .padding(.horizontal, SSpacing.lg)
            .padding(.vertical, SSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SRadius.md)
                    .fill(style == .primary ? Color("sAccent") : Color("sSurface"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SRadius.md)
                    .stroke(Color("sBorder"), lineWidth: style == .secondary ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil)
    }
}

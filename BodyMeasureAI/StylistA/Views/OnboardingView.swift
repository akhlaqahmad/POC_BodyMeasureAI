//
//  OnboardingView.swift
//  BodyMeasureAI
//
//  Simple input screen before scan: height and gender. Stores inputs in ViewModel.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var heightCm: Double
    @Binding var isFemale: Bool
    var onStartScan: () -> Void
    var onOpenHistory: () -> Void

    @State private var heightText: String = ""
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

                    Text("Scan once. Dress perfectly.")
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

                    // Height
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

                    // Gender
                    VStack(alignment: .leading, spacing: SSpacing.sm) {
                        Text("GENDER")
                            .font(SFont.label(11))
                            .tracking(2)
                            .foregroundStyle(Color("sTertiary"))

                        Picker("", selection: Binding<String>(
                            get: { isFemale ? "female" : "male" },
                            set: { newValue in
                                isFemale = (newValue == "female")
                            }
                        )) {
                            Text("Male").tag("male")
                            Text("Female").tag("female")
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

                Spacer().frame(height: SSpacing.xl)

                // CTA
                Button(action: {
                    if let v = Double(heightText), v > 0 { heightCm = v }
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil)
                    onStartScan()
                }) {
                    HStack {
                        Text("Start Scan")
                            .font(SFont.label(15))
                            .tracking(1)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color("sBackground"))
                    .padding(.horizontal, SSpacing.lg)
                    .padding(.vertical, SSpacing.md)
                    .background(Color("sAccent"))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                }
                .padding(.horizontal, SSpacing.lg)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.55), value: appeared)

                Spacer().frame(height: SSpacing.xxl)
            }
        }
        .onAppear { appeared = true }
    }
}

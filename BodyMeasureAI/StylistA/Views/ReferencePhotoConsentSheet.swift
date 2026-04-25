//
//  ReferencePhotoConsentSheet.swift
//  BodyMeasureAI
//
//  Opt-in prompt shown the first time the user starts a body scan. Asks
//  whether to retain RGB keyframes + silhouette masks per angle so a future
//  3D-mesh pipeline can use them as reference inputs. The choice is
//  persisted in `ScanAssetSettings` and only re-shown if the user clears
//  app data.
//

import SwiftUI

struct ReferencePhotoConsentSheet: View {
    var onDecision: (Bool) -> Void

    var body: some View {
        VStack(spacing: SSpacing.lg) {
            // Header
            VStack(spacing: SSpacing.sm) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color("sAccent"))
                    .padding(.top, SSpacing.lg)

                Text("Keep your reference photos?")
                    .font(SFont.display(24, weight: .light))
                    .foregroundStyle(Color("sPrimary"))
                    .multilineTextAlignment(.center)

                Text("Your scan currently produces measurements only. Saving the\nphotos lets us build a 3D body model later, without you re-scanning.")
                    .font(SFont.body(14))
                    .foregroundStyle(Color("sSecondary"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, SSpacing.md)
            }

            // What gets stored
            VStack(alignment: .leading, spacing: SSpacing.sm) {
                bulletRow(icon: "camera", title: "1 photo per angle", subtitle: "Front, side, back — captured at the moment you tap.")
                bulletRow(icon: "person.fill.viewfinder", title: "Silhouette outline", subtitle: "A black-and-white body shape used to refine measurements.")
                bulletRow(icon: "lock.shield", title: "Stored privately", subtitle: "Tied to your device, auto-deleted after 90 days unless you renew.")
            }
            .padding(SSpacing.md)
            .background(Color("sSurface"))
            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
            .padding(.horizontal, SSpacing.lg)

            Spacer()

            // Actions
            VStack(spacing: SSpacing.sm) {
                Button {
                    ScanAssetSettings.record(consent: true)
                    onDecision(true)
                } label: {
                    Text("ALLOW")
                        .font(SFont.label(14))
                        .tracking(2)
                        .foregroundStyle(Color("sBackground"))
                        .padding(.vertical, SSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(Color("sAccent"))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    ScanAssetSettings.record(consent: false)
                    onDecision(false)
                } label: {
                    Text("Not now — measurements only")
                        .font(SFont.body(14))
                        .foregroundStyle(Color("sSecondary"))
                        .padding(.vertical, SSpacing.sm)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SSpacing.lg)
            .padding(.bottom, SSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("sBackground"))
    }

    @ViewBuilder
    private func bulletRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: SSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color("sAccent"))
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SFont.label(13))
                    .foregroundStyle(Color("sPrimary"))
                Text(subtitle)
                    .font(SFont.body(12))
                    .foregroundStyle(Color("sSecondary"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

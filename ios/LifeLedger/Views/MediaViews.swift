import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct MediaPicker: UIViewControllerRepresentable {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    var imagesOnly = false
    var onSelect: ([Attachment]) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = imagesOnly ? .images : .any(of: [.images, .videos, .livePhotos])
        config.selectionLimit = imagesOnly ? 1 : 10
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPicker
        init(_ parent: MediaPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.view.isUserInteractionEnabled = false
            let spinner = UIActivityIndicatorView(style: .large)
            spinner.center = picker.view.center; spinner.startAnimating(); picker.view.addSubview(spinner)
            Task { @MainActor in
                var attachments: [Attachment] = []
                do {
                    for result in results {
                        let provider = result.itemProvider
                        if !parent.imagesOnly && provider.canLoadObject(ofClass: PHLivePhoto.self) {
                            let live: PHLivePhoto = try await withCheckedThrowingContinuation { continuation in
                                provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
                                    if let live = object as? PHLivePhoto { continuation.resume(returning: live) }
                                    else { continuation.resume(throwing: error ?? LedgerError.missingMedia) }
                                }
                            }
                            let resources = PHAssetResource.assetResources(for: live)
                            guard let photo = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }), let video = resources.first(where: { $0.type == .pairedVideo || $0.type == .fullSizePairedVideo }) else { throw LedgerError.missingMedia }
                            let photoPath = try await copyResource(photo)
                            do {
                                let videoPath = try await copyResource(video)
                                attachments.append(Attachment(path: photoPath, kind: "live", pairedVideo: videoPath))
                            } catch { try? FileManager.default.removeItem(at: parent.store.mediaURL(photoPath)); throw error }
                        } else {
                            let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
                            let type = isVideo ? UTType.movie.identifier : UTType.image.identifier
                            let root = parent.store.root
                            let path: String = try await withCheckedThrowingContinuation { continuation in
                                provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                                    do {
                                        guard let url else { throw error ?? LedgerError.missingMedia }
                                        let path = "media/\(UUID().uuidString).\(url.pathExtension.isEmpty ? (isVideo ? "mov" : "jpg") : url.pathExtension)"
                                        let destination = root.appendingPathComponent(path)
                                        try FileManager.default.copyItem(at: url, to: destination)
                                        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
                                        continuation.resume(returning: path)
                                    } catch { continuation.resume(throwing: error) }
                                }
                            }
                            attachments.append(Attachment(path: path, kind: isVideo ? "video" : "image"))
                        }
                    }
                    parent.onSelect(attachments)
                } catch { parent.store.removeMedia(attachments); parent.store.error = error.localizedDescription }
                parent.dismiss()
            }
        }
        @MainActor
        func copyResource(_ resource: PHAssetResource) async throws -> String {
            let path = "media/\(UUID().uuidString).\(URL(fileURLWithPath: resource.originalFilename).pathExtension)"
            let url = parent.store.mediaURL(path)
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    let options = PHAssetResourceRequestOptions(); options.isNetworkAccessAllowed = true
                    PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                return path
            } catch { try? FileManager.default.removeItem(at: url); throw error }
        }
    }
}
struct NoteEditor: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    @State private var note: Note
    @State private var picker = false
    @State private var added: [Attachment] = []
    @State private var saved = false
    init(achievementID: UUID, note: Note? = nil) { _note = State(initialValue: note ?? Note(achievementID: achievementID, text: "")) }
    var body: some View {
        Form {
            Section(store.t("记下当时的细节", "Capture the details")) { TextEditor(text: $note.text).frame(minHeight: 160).accessibilityIdentifier("noteText") }
            Section {
                ForEach(note.attachments) { attachment in
                    HStack { MediaThumbnail(attachment: attachment).frame(width: 65, height: 65).clipShape(RoundedRectangle(cornerRadius: 12)); Text(store.t(attachment.kind == "video" ? "视频" : attachment.kind == "live" ? "实况照片" : "照片", attachment.kind == "video" ? "Video" : attachment.kind == "live" ? "Live Photo" : "Photo")); Spacer(); Button(role: .destructive) { note.attachments.removeAll { $0.id == attachment.id } } label: { Image(systemName: "minus.circle") } }
                }
                Button { picker = true } label: { Label(store.t("添加照片 / 视频 / 实况照片", "Add photos / videos / Live Photos"), systemImage: "photo.on.rectangle") }
            } footer: { Text(store.t("所选媒体会复制到应用内，原图删除后仍可回看。", "Selected media is copied into the app and remains available if the original is deleted.")) }
        }.navigationTitle(store.t("笔记", "Note")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(store.t("取消", "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.t("保存", "Save")) {
                    note.updatedAt = Date()
                    if store.saveNote(note) { saved = true; dismiss() }
                }.disabled(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && note.attachments.isEmpty).accessibilityIdentifier("saveNote") }
            }.sheet(isPresented: $picker) { MediaPicker { items in added += items; note.attachments += items } }
            .onDisappear { store.removeMedia(added.filter { !saved || !note.attachments.contains($0) }) }
    }
}
struct NoteSection: View {
    @EnvironmentObject var store: LedgerStore
    let note: Note
    @State private var editing = false
    @State private var deleting = false
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text(store.date(note.createdAt, full: true)).font(.caption).foregroundStyle(.secondary); Spacer(); Menu {
                    Button(store.t("编辑笔记", "Edit note"), systemImage: "pencil") { editing = true }
                    Button(store.t("删除笔记", "Delete note"), systemImage: "trash", role: .destructive) { deleting = true }
                } label: { Image(systemName: "ellipsis") } }
                if !note.text.isEmpty { Text(note.text).font(.subheadline).lineSpacing(5).textSelection(.enabled) }
                if !note.attachments.isEmpty { LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))]) { ForEach(note.attachments) { item in MediaTile(attachment: item) } } }
            }
        }.sheet(isPresented: $editing) { NavigationStack { NoteEditor(achievementID: note.achievementID, note: note) } }
            .alert(store.t("删除这条笔记？", "Delete this note?"), isPresented: $deleting) {
                Button(store.t("删除", "Delete"), role: .destructive) { store.deleteNote(note) }
                Button(store.t("取消", "Cancel"), role: .cancel) { }
            }
    }
}
struct MediaThumbnail: View {
    @EnvironmentObject var store: LedgerStore
    let attachment: Attachment
    @State private var preview: UIImage?
    var body: some View {
        ZStack {
            Color.ledgerAccent.opacity(0.06)
            if let image = preview { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: attachment.kind == "video" ? "video" : "photo").foregroundStyle(.secondary) }
            if attachment.kind == "video" { Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.white).shadow(radius: 3) }
            if attachment.kind == "live" { VStack { HStack { Image(systemName: "livephoto").font(.caption).foregroundStyle(.white).shadow(radius: 2); Spacer() }; Spacer() }.padding(7) }
        }.clipped().task(id: attachment.id) {
            let url = store.mediaURL(attachment.path)
            if attachment.kind == "video" {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url)); generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 400, height: 400)
                if let result = try? await generator.image(at: .zero) { preview = UIImage(cgImage: result.image) }
            } else {
                let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
                if let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions), let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) { preview = UIImage(cgImage: image) }
            }
        }
    }
}
struct MediaTile: View {
    @EnvironmentObject var store: LedgerStore
    let attachment: Attachment
    @State private var viewing = false
    @State private var playLive = false
    var body: some View {
        Button { playLive = false; viewing = true } label: {
            MediaThumbnail(attachment: attachment).frame(height: 110).clipped()
        }.buttonStyle(.borderless)
            .contextMenu {
                if attachment.pairedVideo != nil {
                    Button(store.t("播放实况照片", "Play Live Photo"), systemImage: "livephoto") { playLive = true; viewing = true }
                }
            }
            .accessibilityLabel(store.t("查看媒体", "View media"))
            .sheet(isPresented: $viewing) { NavigationStack { MediaViewer(attachment: attachment, playLive: playLive) } }

    }
}
struct MediaViewer: View {
    @EnvironmentObject var store: LedgerStore
    @Environment(\.dismiss) var dismiss
    let attachment: Attachment
    var playLive = false
    @State private var player: AVPlayer?
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player { VideoPlayer(player: player) }
            else if let image = UIImage(contentsOfFile: store.mediaURL(attachment.path).path) { Image(uiImage: image).resizable().scaledToFit() }
        }.toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("完成", "Done")) { dismiss() } } }
            .onAppear {
                let path = attachment.kind == "video" ? attachment.path : (playLive ? attachment.pairedVideo : nil)
                if let path { let p = AVPlayer(url: store.mediaURL(path)); player = p; p.play() }
            }.onDisappear { player?.pause() }
    }
}

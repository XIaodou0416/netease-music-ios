import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - 封面毛玻璃背景（UIKit 独立图层，不参与 SwiftUI 布局）
//
// 为什么这样做不会错乱：
// - 背景封面的加载/模糊/换图全部在 UIKit 层（CoverBlurView）内完成，
//   不经过 SwiftUI 的 @State / body 重算，因此封面加载完成不会触发
//   任何 SwiftUI 布局更新 —— 从根上消除"封面加载后布局错乱"。
// - 该视图在 SwiftUI 中只占一个固定全屏 frame（maxWidth/maxHeight: infinity），
//   图片是否加载、加载哪张图都不改变它的尺寸。
// - 切歌换图使用 UIView 交叉溶解过渡，视觉平滑。
//
// 发热优化：不使用 UIVisualEffectView 实时模糊（整屏 GPU 实时模糊是发热大头），
// 而是切歌时在后台队列一次性生成高斯模糊封面图并缓存，前台只做静态显示，
// 效果更明显且几乎零持续开销。

struct CoverBlurBackground: UIViewRepresentable {
    let url: URL?
    let scheme: ColorScheme

    func makeUIView(context: Context) -> CoverBlurView {
        let view = CoverBlurView()
        view.updateScheme(scheme)
        view.load(url: url)
        return view
    }

    func updateUIView(_ uiView: CoverBlurView, context: Context) {
        uiView.updateScheme(scheme)
        uiView.load(url: url)
    }
}

final class CoverBlurView: UIView {
    private let imageView = UIImageView()
    private let tintView = UIView()
    private var currentURL: URL?
    private static let imageCache = NSCache<NSURL, UIImage>()
    private static let blurQueue = DispatchQueue(label: "beans.coverblur", qos: .utility)
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isUserInteractionEnabled = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        tintView.isUserInteractionEnabled = false

        addSubview(imageView)
        addSubview(tintView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        tintView.frame = bounds
    }

    func updateScheme(_ scheme: ColorScheme) {
        // 深浅遮罩：压暗/提亮背景，保证前景文字与控件始终可读
        tintView.backgroundColor = scheme == .dark
            ? UIColor.black.withAlphaComponent(0.42)
            : UIColor.white.withAlphaComponent(0.20)
    }

    func load(url: URL?) {
        guard let url else {
            imageView.image = nil
            return
        }
        currentURL = url

        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            setImage(cached, animated: false)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let source = UIImage(data: data) else { return }
            Self.blurQueue.async {
                guard let blurred = Self.makeBlurredImage(source) else { return }
                Self.imageCache.setObject(blurred, forKey: url as NSURL)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentURL == url else { return }
                    self.setImage(blurred, animated: true)
                }
            }
        }.resume()
    }

    /// 一次性高斯模糊：先缩小再模糊，最后放回全屏展示，观感更明显、开销更低
    private static func makeBlurredImage(_ source: UIImage) -> UIImage? {
        let target = source.preparingThumbnail(of: CGSize(width: 480, height: 480)) ?? source
        guard let input = CIImage(image: target) else { return target }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input
        filter.radius = 36
        guard let output = filter.outputImage else { return target }
        let extent = output.extent
        guard extent.width > 0, extent.height > 0,
              let cg = ciContext.createCGImage(output, from: extent) else { return target }
        return UIImage(cgImage: cg)
    }

    private func setImage(_ image: UIImage, animated: Bool) {
        guard animated, imageView.image != nil else {
            imageView.image = image
            return
        }
        UIView.transition(
            with: imageView,
            duration: 0.4,
            options: [.transitionCrossDissolve, .beginFromCurrentState]
        ) {
            self.imageView.image = image
        }
    }
}

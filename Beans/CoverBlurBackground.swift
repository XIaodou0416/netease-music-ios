import SwiftUI
import UIKit

// MARK: - 封面毛玻璃背景（UIKit 独立图层，不参与 SwiftUI 布局）
//
// 为什么这样做不会错乱：
// - 背景封面的加载/模糊/换图全部在 UIKit 层（CoverBlurView）内完成，
//   不经过 SwiftUI 的 @State / body 重算，因此封面加载完成不会触发
//   任何 SwiftUI 布局更新 —— 从根上消除"封面加载后布局错乱"。
// - 该视图在 SwiftUI 中只占一个固定全屏 frame（maxWidth/maxHeight: infinity），
//   图片是否加载、加载哪张图都不改变它的尺寸。
// - 切歌换图使用 UIView 交叉溶解过渡，视觉平滑。

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
    private let blurView = UIVisualEffectView()
    private let shadeView = UIView()
    private var currentURL: URL?
    private static let cache = NSCache<NSURL, UIImage>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isUserInteractionEnabled = false

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        shadeView.isUserInteractionEnabled = false
        blurView.isUserInteractionEnabled = false

        addSubview(imageView)
        addSubview(blurView)
        addSubview(shadeView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        blurView.frame = bounds
        shadeView.frame = bounds
    }

    func updateScheme(_ scheme: ColorScheme) {
        blurView.effect = UIBlurEffect(
            style: scheme == .dark ? .systemChromeMaterialDark : .systemChromeMaterialLight
        )
        // 深浅遮罩：保证前景文字/控件始终可读
        shadeView.backgroundColor = scheme == .dark
            ? UIColor.black.withAlphaComponent(0.42)
            : UIColor.white.withAlphaComponent(0.30)
    }

    func load(url: URL?) {
        guard let url else {
            imageView.image = nil
            return
        }
        currentURL = url

        if let cached = Self.cache.object(forKey: url as NSURL) {
            setImage(cached, animated: false)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            Self.cache.setObject(image, forKey: url as NSURL)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentURL == url else { return }
                self.setImage(image, animated: true)
            }
        }.resume()
    }

    private func setImage(_ image: UIImage, animated: Bool) {
        guard animated, imageView.image != nil else {
            imageView.image = image
            return
        }
        UIView.transition(
            with: imageView,
            duration: 0.35,
            options: [.transitionCrossDissolve, .beginFromCurrentState]
        ) {
            self.imageView.image = image
        }
    }
}

#if os(macOS)
  import Cocoa
#else
  import UIKit
#endif

/// A concrete layout object that is a subclass of collection view flow layout.
/// This class is meant to be subclasses and not used directly.
/// When subclassing, your subclass should implement `prepare` with the
/// layout algorithm that your subclass should implement.
open class BlueprintLayout : CollectionViewFlowLayout {
  override open var collectionViewContentSize: CGSize { return contentSize }
  /// The amount of items that should appear on each row.
  public var itemsPerRow: CGFloat?
  /// A layout attributes cache, gets invalidated with the collection view and filled using the `prepare` method.
  public var layoutAttributes = [[LayoutAttributes]]()
  /// The content size of the layout, should be set using the `prepare` method of any subclass.
  public var contentSize: CGSize = CGSize(width: 50, height: 50)
  /// The number of sections in the collection view.
  var numberOfSections: Int { return resolveCollectionView({ $0.dataSource?.numberOfSections?(in: $0) },
                                                           defaultValue: 1) }
  /// A layout animator object, defaults to `DefaultLayoutAnimator`.
  var animator: BlueprintLayoutAnimator

  /// An initialized collection view layout object.
  ///
  /// - Parameters:
  ///   - itemsPerRow: The amount of items that should appear on each row.
  ///   - itemSize: The default size to use for cells.
  ///   - minimumInteritemSpacing: The minimum spacing to use between items in the same row.
  ///   - minimumLineSpacing: The minimum spacing to use between lines of items in the grid.
  ///   - sectionInset: The margins used to lay out content in a section
  ///   - animator: The animator that should be used for the layout, defaults to `DefaultLayoutAnimator`.
  public init(
    itemsPerRow: CGFloat? = nil,
    itemSize: CGSize = CGSize(width: 50, height: 50),
    minimumInteritemSpacing: CGFloat = 10,
    minimumLineSpacing: CGFloat = 10,
    sectionInset: EdgeInsets = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
    animator: BlueprintLayoutAnimator = DefaultLayoutAnimator()
    ) {
    self.itemsPerRow = itemsPerRow
    self.animator = animator
    super.init()
    self.itemSize = itemSize
    self.minimumInteritemSpacing = minimumInteritemSpacing
    self.minimumLineSpacing = minimumLineSpacing
    self.sectionInset = sectionInset
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Tells the layout object to update the current layout.
  open override func prepare() {
    self.contentSize = .zero
    self.layoutAttributes = []
  }

  /// Creates layout attributes for a header.
  ///
  /// - Parameters:
  ///   - indexPath: The index path of the section that the footer belongs to.
  ///   - x: The x coordinate of the header layout attributes.
  ///   - y: The y coordinate of the header layout attributes.
  /// - Returns: A `LayoutAttributes` object of supplementary kind header.
  func createHeader(_ indexPath: IndexPath, atX x: CGFloat = 0, atY y: CGFloat = 0) -> LayoutAttributes {
    let layoutAttribute = LayoutAttributes(
      forSupplementaryViewOfKind: CollectionView.collectionViewHeaderType,
      with: indexPath
    )
    layoutAttribute.zIndex = indexPath.section
    layoutAttribute.size.height = headerReferenceSize.height
    layoutAttribute.frame.origin.x = x
    layoutAttribute.frame.origin.y = y

    return layoutAttribute
  }

  /// Creates layout attributes for a footer.
  ///
  /// - Parameters:
  ///   - indexPath: The index path of the section that the footer belongs to.
  ///   - x: The x coordinate of the footer layout attributes.
  ///   - y: The y coordinate of the footer layout attributes.
  /// - Returns: A `LayoutAttributes` object of supplementary kind footer.
  func createFooter(_ indexPath: IndexPath, atX x: CGFloat = 0, atY y: CGFloat = 0) -> LayoutAttributes {
    let layoutAttribute = LayoutAttributes(
      forSupplementaryViewOfKind: CollectionView.collectionViewFooterType,
      with: indexPath
    )
    layoutAttribute.zIndex = indexPath.section
    layoutAttribute.size.height = footerReferenceSize.height
    layoutAttribute.frame.origin.x = x
    layoutAttribute.frame.origin.y = y + sectionInset.bottom

    return layoutAttribute
  }

  /// Returns the layout attributes for the item at the specified index path.
  ///
  /// - Parameter indexPath: The index path of the item whose attributes are requested.
  /// - Returns: A layout attributes object containing the information to apply to the item’s cell.
  override open func layoutAttributesForItem(at indexPath: IndexPath) -> LayoutAttributes? {
    guard indexPath.section < layoutAttributes.count else {
      return nil
    }

    guard indexPath.item < layoutAttributes[indexPath.section].count else {
      return nil
    }

    return layoutAttributes[indexPath.section][indexPath.item]
  }

  /// Returns the layout attributes for all of the cells and views
  /// in the specified rectangle.
  ///
  /// - Parameter rect: The rectangle (specified in the collection view’s coordinate system) containing the target views.
  /// - Returns: An array of layout attribute objects containing the layout information for the enclosed items and views.
  override open func layoutAttributesForElements(in rect: CGRect) -> LayoutAttributesForElements {
    return layoutAttributes.flatMap { $0 }.filter { $0.frame.intersects(rect) }
  }

  /// Returns the starting layout information for an item being inserted into the collection view.
  ///
  /// - Parameter itemIndexPath: The index path of the item being inserted.
  override open func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> LayoutAttributes? {
    guard let attributes = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath) else {
      return nil
    }

    return animator.initialLayoutAttributesForAppearingItem(at: itemIndexPath,
                                                            with: attributes)
  }

  /// Returns the ending layout information for an item being removed from the collection view.
  ///
  /// - Parameter itemIndexPath: The index path of the item being removed.
  /// - Returns: The layout attributes object that describes the item’s position
  ///            and properties at the end of animations.
  override open func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> LayoutAttributes? {
    guard let attributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath) else {
      return nil
    }

    return animator.finalLayoutAttributesForDisappearingItem(at: itemIndexPath,
                                                             with: attributes)
  }

  /// Notifies the layout object that the contents of the collection view are about to change.
  ///
  /// - Parameter updateItems: An array of CollectionViewUpdateItem objects
  //                           that identify the changes being made.
  override open func prepare(forCollectionViewUpdates updateItems: [CollectionViewUpdateItem]) {
    return animator.prepare(forCollectionViewUpdates: updateItems)
  }

  // MARK: - Internal methods

  /// Queries the data source for the amount of items inside of a section.
  ///
  /// - Parameter section: The section index.
  /// - Returns: The amount items inside of the section.
  func numberOfItemsInSection(_ section: Int) -> Int {
    return resolveCollectionView({ collectionView in
      collectionView.dataSource?.collectionView(collectionView, numberOfItemsInSection: section)
    }, defaultValue: 0)
  }

  /// Calculate width of item based of `itemsPerRow`.
  ///
  /// - Parameters:
  ///   - itemsPerRow: The amount of items that should appear per row.
  ///   - containerWidth: The container width used to calculate the width.
  /// - Returns: The desired width for the item.
  func calculateItemWidth(_ itemsPerRow: CGFloat, containerWidth: CGFloat) -> CGFloat {
    var width = containerWidth - sectionInset.left - sectionInset.right

    if itemsPerRow > 1 {
      width -= minimumInteritemSpacing * (itemsPerRow - 1)
    }

    return floor(width / itemsPerRow)
  }

  /// Resolve the size of item at index path.
  /// If the layout uses `itemsPerRow`, it will compute the size based of the amount of items that
  /// should appear per row using the size of the collection view.
  /// If the collection view's delegate conforms to `(UI/NS)CollectionViewDelegateFlowLayout`, it will
  /// query the delegate for the size of the item.
  /// It defaults to using the `itemSize` property on collection view flow layout.
  ///
  /// - Parameter indexPath: The index path of the item.
  /// - Returns: The desired size of the item at the index path.
  func resolveSizeForItem(at indexPath: IndexPath) -> CGSize {
    if let collectionView = collectionView, let itemsPerRow = itemsPerRow, itemsPerRow > 0 {
      let containerWidth: CGFloat
      #if os(macOS)
        containerWidth = collectionView.enclosingScrollView?.frame.width ?? collectionView.frame.size.width
      #else
        containerWidth = collectionView.frame.size.width
      #endif

      let size = CGSize(
        width: calculateItemWidth(itemsPerRow, containerWidth: containerWidth),
        height: itemSize.height
      )

      return size
    } else {
      let size = resolveCollectionView({ collectionView -> CGSize? in
        return (collectionView.delegate as? CollectionViewFlowLayoutDelegate)?.collectionView?(collectionView,
                                                                                               layout: self,
                                                                                               sizeForItemAt: indexPath)
      }, defaultValue: itemSize)

      return size
    }
  }

  // MARK: - Private methods

  /// Resolve collection collection view from layout and return
  /// property or default value if collection view cannot be resolved.
  ///
  /// - Parameters:
  ///   - closure: A closure that takes a collectino view resolved from
  ///              the layout.
  ///   - defaultValue: A default value if the collection view cannot be
  ///                   resolved, it also infers type.
  /// - Returns: A property from the closure or the default value if the
  ///            closure returns `nil`.
  private func resolveCollectionView<T>(_ closure: (CollectionView) -> T?, defaultValue: T) -> T {
    if let collectionView = collectionView {
      return closure(collectionView) ?? defaultValue
    } else {
      return defaultValue
    }
  }
}

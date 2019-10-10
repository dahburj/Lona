//
//  MarkdownViewController.swift
//  LonaStudio
//
//  Created by Devin Abbott on 6/29/19.
//  Copyright © 2019 Devin Abbott. All rights reserved.
//

import AppKit
import Logic

// MARK: - MarkdownViewController

class MarkdownViewController: NSViewController {

    // MARK: Lifecycle

    convenience init(editable: Bool, preview: Bool) {
        self.init(nibName: nil, bundle: nil)

        self.editable = editable
        self.preview = preview
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    // MARK: Public

    public var editable: Bool = true

    public var preview: Bool = true

    public var content: [BlockEditor.Block] = [] { didSet { update() } }

    public var onChange: (([BlockEditor.Block]) -> Bool)? {
        get { return contentView.onChangeBlocks }
        set { contentView.onChangeBlocks = newValue }
    }

    // MARK: Private

    override func loadView() {

        setUpViews()
        setUpConstraints()

        update()
    }

    private let containerView = NSBox()
    private var contentView = BlockEditor()

    private func setUpViews() {
        containerView.borderType = .noBorder
        containerView.boxType = .custom
        containerView.contentViewMargins = .zero
        containerView.fillColor = Colors.contentBackground

        containerView.addSubview(contentView)

        contentView.fillColor = .clear

        view = contentView
    }

    private func setUpConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        contentView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
    }

    private func update() {
        contentView.blocks = content
        configure(blocks: content)
    }
}

// MARK: - Editor Configuration

extension MarkdownViewController {

    private func configure(blocks: [BlockEditor.Block]) {

        let compiled = LonaModule.current.logic.compiled

        // TODO: topLevelDeclarations and program are created with a new ID each time, will that hurt performance?
        guard let root = LGCProgram.make(from: .topLevelDeclarations(blocks.topLevelDeclarations)) else { return }

        let rootNode = LGCSyntaxNode.program(root)

        let formattingOptions: LogicFormattingOptions = LogicFormattingOptions(
            style: .visual,
            getError: ({ id in
                if let error = compiled.errors.first(where: { $0.uuid == id }) {
                    return error.message
                } else {
                    return nil
                }
            }),
            getArguments: ({ id in
                return StandardConfiguration.formatArguments(
                    rootNode: rootNode,
                    id: id,
                    unificationContext: compiled.unification?.0,
                    substitution: compiled.unification?.1
                )
            }),
            getColor: ({ id in
                guard let evaluation = compiled.evaluation else { return nil }
                guard let value = evaluation.evaluate(uuid: id) else { return nil }
                guard let colorString = value.colorString, let color = NSColor.parse(css: colorString) else { return nil }
                return (colorString, color)
            }),
            getTextStyle: ({ id in
                guard let evaluation = compiled.evaluation else { return nil }
                guard let value = evaluation.evaluate(uuid: id) else { return nil }
                return value.textStyle
            }),
            getShadow: ({ id in
                guard let evaluation = compiled.evaluation else { return nil }
                guard let value = evaluation.evaluate(uuid: id) else { return nil }
                return value.nsShadow
            })
        )

        let suggestionsForNode: ((LGCSyntaxNode, LGCSyntaxNode, String) -> [LogicSuggestionItem]) = { _, node, query in
            let compiled = LonaModule.current.logic.compiled

            let suggestionBuilder = StandardConfiguration.suggestions(rootNode: compiled.programNode, node: node, formattingOptions: formattingOptions)

            if let suggestionBuilder = suggestionBuilder, let suggestions = suggestionBuilder(query) {
                return suggestions
            } else {
                return node.suggestions(within: rootNode, for: query)
            }
        }

        blocks.forEach { block in
            switch block.content {
            case .tokens:
                let logicEditor = block.view as! LogicEditor

                logicEditor.formattingOptions = formattingOptions

                logicEditor.suggestionsForNode = suggestionsForNode

                // Only show the errors for nodes within this rootNode
                logicEditor.elementErrors = compiled.errors.filter { logicEditor.rootNode.find(id: $0.uuid) != nil }

                logicEditor.willSelectNode = { rootNode, nodeId in
                    guard let nodeId = nodeId else { return nil }

                    return rootNode.redirectSelection(nodeId)
                }

                logicEditor.documentationForSuggestion = { rootNode, suggestionItem, query, formattingOptions, builder in
                    switch suggestionItem.node {
                    case .expression(.literalExpression(id: _, literal: .color(id: _, value: let css))),
                         .literal(.color(id: _, value: let css)):

                        let decodeValue: (Data?) -> SwiftColor = { data in
                            if let data = data, let cssString = String(data: data, encoding: .utf8) {
                                return SwiftColor(cssString: cssString)
                            } else {
                                // Improve the empty state by setting alpha to 1 initially
                                if css == "" {
                                    return SwiftColor(red: 0, green: 0, blue: 0)
                                }
                                return SwiftColor(cssString: css)
                            }
                        }

                        var colorValue = decodeValue(builder.initialValue)
                        let view = ColorSuggestionEditor(colorValue: colorValue)

                        view.onChangeColorValue = { color in
                            colorValue = color

                            // Setting the color to nil is a hack to force the color picker to re-draw even if the color values are equal.
                            // The Color library tests for equality in a way that prevents us from changing the hue of the color when the
                            // saturation and lightness are 0.
                            view.colorValue = nil
                            view.colorValue = colorValue

                            builder.setListItem(.colorRow(name: "Color", code: color.cssString, color.NSColor, false))

                            if let data = colorValue.cssString.data(using: .utf8) {
                                builder.onChangeValue(data)
                            }
                        }

                        view.onSubmit = {
                            builder.onSubmit()
                        }

                        builder.setNodeBuilder({ data in
                            let cssValue = data != nil ? decodeValue(data).cssString : css
                            let literal = LGCLiteral.color(id: UUID(), value: cssValue)
                            switch suggestionItem.node {
                            case .literal:
                                return .literal(literal)
                            case .expression:
                                return .expression(.literalExpression(id: UUID(), literal: literal))
                            default:
                                fatalError("Unsupported node")
                            }
                        })

                        return view
                    default:
                        return LogicEditor.defaultDocumentationForSuggestion(rootNode, suggestionItem, query, formattingOptions, builder)
                    }
                }
            default:
                break
            }
        }
    }
}

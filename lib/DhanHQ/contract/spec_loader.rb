# frozen_string_literal: true

require "json"

module DhanHQ
  module Contract
    # Loads the vendored DhanHQ OpenAPI documents from +contracts/dhanhq/+ and
    # applies the curated RFC 6902 overlays from +contracts/overlays/+.
    #
    # The vendor spec is never edited in place: overlays are separate, reviewed
    # JSON Patch files so a clean re-download (rake contract:refresh) can replace
    # the base document without losing our decisions. Every overlay is documented
    # in contracts/overlays/README.md.
    class SpecLoader
      SPECS_DIR = File.expand_path("../../../contracts/dhanhq", __dir__)
      OVERLAYS_DIR = File.expand_path("../../../contracts/overlays", __dir__)

      # Which overlays apply to which document, in application order.
      OVERLAYS = {
        live: [
          "0001-docs-only-endpoints.jsonpatch",
          "0002-rate-limit-annotations.jsonpatch",
          "0005-enum-reconciliation.jsonpatch",
          "0006-type-reconciliation.jsonpatch"
        ],
        sandbox: [
          "0003-sandbox-quirks.jsonpatch",
          "0004-sandbox-verified-additions.jsonpatch"
        ]
      }.freeze

      class << self
        # Loads a vendored spec and applies its overlays. Memoized and frozen —
        # treat the result as immutable.
        #
        # @param name [Symbol] +:live+ or +:sandbox+
        # @return [Hash] The effective contract document
        def load(name)
          @cache ||= {}
          @cache[name] ||= begin
            doc = JSON.parse(File.read(spec_path(name), encoding: "UTF-8"))
            apply_overlays!(doc, name)
            doc.freeze
          end
        end

        # Loads the raw (unpatched) vendored spec — used by rake contract:check
        # to compare a fresh download against the committed base document.
        #
        # @param name [Symbol]
        # @return [Hash]
        def load_raw(name)
          JSON.parse(File.read(spec_path(name), encoding: "UTF-8"))
        end

        # @param name [Symbol]
        # @return [String] Absolute path of the vendored spec file
        def spec_path(name)
          File.join(SPECS_DIR, "#{name}.openapi.json")
        end

        # Applies a minimal but correct RFC 6902 subset: add / remove / replace.
        # (The overlays only use these three operations; supporting them exactly
        # keeps the gem dependency-free on this path.)
        #
        # @param doc [Hash] Document mutated in place
        # @param patch [Array<Hash>] RFC 6902 operations
        # @return [Hash] The same document
        def apply_patch!(doc, patch)
          patch.each do |entry|
            pointer = entry.fetch("path")
            case entry.fetch("op")
            when "add"     then pointer_set(doc, pointer, entry.fetch("value"))
            when "replace" then pointer_replace(doc, pointer, entry.fetch("value"))
            when "remove"  then pointer_remove(doc, pointer)
            else
              raise ArgumentError, "Unsupported JSON Patch op: #{entry["op"].inspect}"
            end
          end
          doc
        end

        private

        def apply_overlays!(doc, name)
          OVERLAYS.fetch(name, []).each do |file|
            patch = JSON.parse(File.read(File.join(OVERLAYS_DIR, file), encoding: "UTF-8"))
            apply_patch!(doc, patch)
          rescue Errno::ENOENT
            raise "Overlay #{file} referenced for :#{name} but missing in #{OVERLAYS_DIR}"
          end
          doc
        end

        # -- JSON Pointer (RFC 6901) helpers ---------------------------------

        def parse_pointer(pointer)
          raise ArgumentError, "JSON Pointer must start with /: #{pointer}" unless pointer.start_with?("/")

          pointer.split("/")[1..].map { |t| t.gsub("~1", "/").gsub("~0", "~") }
        end

        # Sets (creating intermediate objects as needed) the value at pointer.
        # "-" as the final token appends to an array.
        def pointer_set(doc, pointer, value)
          tokens = parse_pointer(pointer)
          *parents, last = tokens
          target = walk(doc, parents, create: true)

          case target
          when Array
            if last == "-"
              target << value
            else
              target[last.to_i] = value
            end
          when Hash
            target[last] = value
          else
            raise ArgumentError, "Cannot set #{pointer}: parent is #{target.class}"
          end
          doc
        end

        def pointer_replace(doc, pointer, value)
          tokens = parse_pointer(pointer)
          *parents, last = tokens
          target = walk(doc, parents)
          raise KeyError, "No member at #{pointer}" unless target.is_a?(Hash) && target.key?(last)

          target[last] = value
          doc
        end

        def pointer_remove(doc, pointer)
          tokens = parse_pointer(pointer)
          *parents, last = tokens
          target = walk(doc, parents)
          raise KeyError, "No member at #{pointer}" unless target.is_a?(Hash) && target.key?(last)

          target.delete(last)
          doc
        end

        def walk(node, tokens, create: false)
          tokens.reduce(node) do |acc, token|
            if acc.is_a?(Hash)
              if create && !acc.key?(token)
                acc[token] = {}
              elsif acc.key?(token)
                acc[token]
              else
                raise KeyError, "Pointer segment #{token.inspect} not found"
              end
            elsif acc.is_a?(Array)
              acc[token.to_i]
            else
              raise KeyError, "Cannot walk #{token.inspect} into #{acc.class}"
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Badger
  # Where fonts come from when a badge names one. Directories are scanned
  # for TrueType and OpenType files and a font is addressed by its file
  # name without the extension ("Archivo-Bold"), or by a path.
  module Fonts
    class Unknown < Badger::Error; end

    EXTENSIONS = %w[.ttf .otf].freeze

    @directories = []
    @registry = {}
    @fonts = {}

    class << self
      attr_reader :directories

      def add_directory(dir)
        path = File.expand_path(dir)
        @directories << path unless @directories.include?(path)
        @registry = nil
        self
      end

      def register(name, path)
        (@explicit ||= {})[name.to_s] = File.expand_path(path)
        @registry = nil
        self
      end

      def names = registry.keys.sort

      def path_for(name)
        name = name.to_s
        return File.expand_path(name) if File.file?(name)

        registry.fetch(name) do
          raise Unknown, "no font named #{name.inspect}; known: #{names.join(', ').then { |s| s.empty? ? 'none' : s }}"
        end
      end

      # A Font, shared: shaping caches outlines per font, so one instance
      # per name is what makes a badge with ten runs ten sidecar calls and
      # not ten font loads.
      def font(name)
        @fonts[path_for(name)] ||= Font.new(path_for(name))
      end

      def reset!
        @directories = []
        @explicit = {}
        @registry = nil
        @fonts = {}
        self
      end

      private

      def registry
        @registry ||= @directories.each_with_object({}) do |dir, acc|
          Dir[File.join(dir, "**", "*")].sort.each do |file|
            next unless EXTENSIONS.include?(File.extname(file).downcase)

            acc[File.basename(file, File.extname(file))] ||= file
          end
        end.merge(@explicit ||= {})
      end
    end
  end
end

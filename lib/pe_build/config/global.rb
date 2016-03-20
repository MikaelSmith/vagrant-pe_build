require 'pe_build/config_default'
require 'pe_build/transfer'

require 'uri'

class PEBuild::Config::Global < Vagrant.plugin('2', :config)

  # @!attribute download_root
  #   @return [String] The root URI from which to download packages. The URI
  #     scheme must be one of the values listed in {PEBuild::Transfer::IMPLEMENTATIONS}.
  #   @since 0.1.0
  attr_accessor :download_root

  # @!attribute version
  #   @return [String] The version of PE to install. Must conform to
  #     `x.y.x[-optional-arbitrary-stuff]`. Used to determine the name of the
  #     PE installer archive if `filename` is unset.
  #   @since 0.1.0
  attr_accessor :version

  # @!attribute version_file
  #   @return [String, URI] A fully-qualified URI or a path relative to
  #     `download_root`. The contents of this file will be read and used to
  #     Specify `version`.
  #   @since 0.9.0
  attr_accessor :version_file

  # @!attribute series
  #   @return [String] The release series of PE. Completely optional and
  #     currently has no effect other than being an interpolation token
  #     available for use in `download_root`.
  #
  #   @since 0.9.0
  attr_accessor :series

  # @!attribute suffix
  #   @return [String] The distribution specifix suffix of the Puppet
  #     Enterprise installer to use.
  #   @since 0.1.0
  attr_accessor :suffix

  # @!attribute filename
  #   @return [String] The exact name of the PE installer archive. If missing,
  #     a name will be constructed from {#version}.
  #   @since 0.1.0
  attr_accessor :filename

  # @!attribute shared_installer
  #   @return [Boolean] Whether to run PE installation using installers and
  #     answers shared using the `/vagrant` mount. If set to `false`, resources
  #     will be downloaded remotely to the home directory of whichever user
  #     account Vagrant is using. Defaults to `true`.
  #
  #   @since 0.14.0
  attr_accessor :shared_installer

  def initialize
    @download_root = UNSET_VALUE
    @version       = UNSET_VALUE
    @version_file  = UNSET_VALUE
    @series        = UNSET_VALUE
    @suffix        = UNSET_VALUE
    @filename      = UNSET_VALUE
    @shared_installer = UNSET_VALUE
  end

  include PEBuild::ConfigDefault

  def finalize!
    set_default :@version, nil
    set_default :@version_file, nil
    set_default :@series, nil
    set_default :@suffix, :detect
    set_default :@download_root, nil
    set_default :@filename, nil
    set_default :@shared_installer, true
  end

  def validate(machine)
    errors = []

    validate_version(errors, machine)
    validate_download_root(errors, machine)

    {"PE build global config" => errors}
  end

  private

  PE_VERSION_REGEX = %r[\d+\.\d+\.\d+[\w-]*]

  def validate_version(errors, machine)

    errmsg = I18n.t(
      'pebuild.config.global.errors.malformed_version',
      :version       => @version,
      :version_class => @version.class
    )

    # Allow Global version to be unset, rendering it essentially optional. If it is
    # discovered to be unset by a configuration on the next level up who cannot provide a
    # value, it is that configuration's job to take action.
    if @version.kind_of? String
      if !(@version.match PE_VERSION_REGEX)
        errors << errmsg
      end
    # Allow the version to be either unset or nil. Anything else is an error.
    elsif ![nil, UNSET_VALUE].include? @version
      errors << errmsg
    end
  end

  def validate_download_root(errors, machine)
    if @download_root and @download_root != UNSET_VALUE
      begin
        uri = URI.parse(@download_root)

        if PEBuild::Transfer::IMPLEMENTATIONS[uri.scheme].nil?
          errors << I18n.t(
            'pebuild.config.global.errors.unhandled_download_root_scheme',
            :download_root => @download_root,
            :scheme        => uri.scheme,
            :supported     => PEBuild::Transfer::IMPLEMENTATIONS.keys
          )
        end
      rescue URI::InvalidURIError
        errors << I18n.t('pebuild.config.global.errors.invalid_download_root_uri')
      end
    end
  end
end

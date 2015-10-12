# Configuration for PE Agent provisioners
#
# @since 0.13.0
class PEBuild::Config::PEAgent < Vagrant.plugin('2', :config)
  # The minimum PE Version supported by this provisioner.
  MINIMUM_VERSION    = '2015.2.0'

  # @!attribute master
  #   @return [String] The DNS hostname of the Puppet master for this node.
  attr_accessor :master

  # @!attribute version
  #   @return [String] The version of PE to install. May be either a version
  #   string of the form `x.y.x[-optional-arbitrary-stuff]` or the string
  #   `current`. Defaults to `current`.
  attr_accessor :version

  def initialize
    @master        = UNSET_VALUE
    @version       = UNSET_VALUE
  end

  def finalize!
    @master        = nil if @master == UNSET_VALUE
    @version       = 'current' if @version == UNSET_VALUE
  end

  def validate(machine)
    errors = _detected_errors

    if @master.nil?
      errors << I18n.t('pebuild.config.pe_agent.errors.no_master')
    end

    validate_version!(errors, machine)

    {'pe_agent provisioner' => errors}
  end

  private

  def validate_version!(errors, machine)
    pe_version_regex = %r[\d+\.\d+\.\d+[\w-]*]

    if @version.kind_of? String
      return if version == 'current'
      if version.match(pe_version_regex)
        unless PEBuild::Util::VersionString.compare(@version, MINIMUM_VERSION) > 0
          errors << I18n.t(
            'pebuild.config.pe_agent.errors.version_too_old',
            :version         => @version,
            :minimum_version => MINIMUM_VERSION
          )
        end

        return
      end
    end

    # If we end up here, the version was not a string that matched 'current' or
    # the regex. Mutate the error array.
    errors << I18n.t(
      'pebuild.config.pe_agent.errors.malformed_version',
      :version       => @version,
      :version_class => @version.class
    )
  end
end

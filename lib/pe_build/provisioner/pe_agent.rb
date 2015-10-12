require 'pe_build/util/pe_packaging'
require 'pe_build/util/machine_comms'

module PEBuild
  module Provisioner
    # Provision PE agents using simplified install
    #
    # @since 0.13.0
    class PEAgent < Vagrant.plugin('2', :provisioner)
      include ::PEBuild::Util::PEPackaging
      include ::PEBuild::Util::MachineComms

      attr_reader :facts
      attr_reader :agent_version

      def provision
        provision_init!

        unless agent_version.nil?
          machine.ui.info I18n.t(
            'pebuild.provisioner.pe_agent.already_installed',
            :version => agent_version
          )
          return
        end

        # FIXME: Not necessary if the agent is running Windows.
        unless config.master_vm.nil?
          provision_pe_repo
        end

        # TODO Wrap in a method that handles windows VMs (by calling pe_bootstrap).
        provision_posix_agent

        # TODO Sign agent cert, if master_vm is available.
      end

      private

      # Set data items that are only available at provision time
      def provision_init!
        @facts = machine.guest.capability(:pebuild_facts)
        @agent_version = facts['puppetversion']

        # Resolve the master_vm setting to a Vagrant machine reference.
        unless config.master_vm.nil?
          vm_def = machine.env.active_machines.find {|vm| vm[0].to_s == config.master_vm.to_s}

          unless vm_def.nil?
            config.master_vm = machine.env.machine(*vm_def)
            config.master    ||= config.master_vm.config.vm.hostname.to_s
          end
        end
      end

      # Ensure a master VM is able to serve agent packages
      #
      # This method inspects the master VM and ensures it is configured to
      # serve packages for the agent's architecture.
      def provision_pe_repo
        # This method will raise an error if commands can't be run on the
        # master VM.
        ensure_reachable(config.master_vm)

        platform         = platform_tag(facts)
        # Transform the platform_tag into a Puppet class name.
        pe_repo_platform = platform.gsub('-', '_').gsub('.', '')
        # TODO: Support PE 3.x
        platform_repo    = "/opt/puppetlabs/server/data/packages/public/current/#{platform}"

        # Print a message and return if the agent repositories exist on the
        # master.
        if config.master_vm.communicate.test("[ -e #{platform_repo} ]")
          config.master_vm.ui.info I18n.t(
            'pebuild.provisioner.pe_agent.pe_repo_present',
            :vm_name      => config.master_vm.name,
            :platform_tag => platform
          )
          return
        end

        config.master_vm.ui.info I18n.t(
          'pebuild.provisioner.pe_agent.adding_pe_repo',
          :vm_name      => config.master_vm.name,
          :platform_tag => platform
        )

        shell_config = Vagrant.plugin('2').manager.provisioner_configs[:shell].new
        shell_config.privileged = true
        # TODO: Extend to configuring agent repos which are older than the
        # master.
        # TODO: Extend to PE 3.x masters.
        shell_config.inline = <<-EOS
/opt/puppetlabs/bin/puppet apply -e 'include pe_repo::platform::#{pe_repo_platform}'
        EOS
        shell_config.finalize!

        shell_provisioner = Vagrant.plugin('2').manager.provisioners[:shell].new(config.master_vm, shell_config)
        shell_provisioner.provision
      end

      # Execute a Vagrant shell provisioner to provision POSIX agents
      #
      # Performs a `curl | bash` installation.
      def provision_posix_agent
        shell_config = Vagrant.plugin('2').manager.provisioner_configs[:shell].new
        shell_config.privileged = true
        # TODO: Extend to allow passing agent install options.
        shell_config.inline = <<-EOS
curl -k -tlsv1 -s https://#{config.master}:8140/packages/#{config.version}/install.bash | bash
        EOS
        shell_config.finalize!

        machine.ui.info "Running: #{shell_config.inline}"

        shell_provisioner = Vagrant.plugin('2').manager.provisioners[:shell].new(machine, shell_config)
        shell_provisioner.provision
      end

    end
  end
end

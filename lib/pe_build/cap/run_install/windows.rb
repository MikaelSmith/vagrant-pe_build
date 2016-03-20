require 'pe_build/on_machine'
class PEBuild::Cap::RunInstall::Windows

  extend PEBuild::OnMachine

  def self.run_install(machine, config, archive)
    root = machine.communicate.shell.cmd('ECHO %SYSTEMDRIVE%')[:data][0][:stdout].chomp
    root = File.join("#{root}\\vagrant", PEBuild::WORK_DIR)

    # The installer will be fed to msiexec. That means the File.join() method
    # is of limited use since it won't execute on the Windows system
    installer = File.join(root, archive.to_s).gsub('/', '\\')

    cmd = []
    cmd << 'msiexec' << '/qn' << '/i' << installer

    cmd << "PUPPET_MASTER_SERVER=#{config.master}"
    cmd << "PUPPET_AGENT_CERTNAME=#{machine.name}"

    argv = cmd.join(' ')

    on_machine(machine, argv)

  end
end

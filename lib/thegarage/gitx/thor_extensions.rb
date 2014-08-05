class Thor
  module Actions
    # launch configured editor to retreive message/string
    # see http://osdir.com/ml/ruby-talk/2010-06/msg01424.html
    # see https://gist.github.com/rkumar/456809
    # see http://rdoc.info/github/visionmedia/commander/master/Commander/UI.ask_editor
    def ask_editor(initial_text = '')
      Tempfile.open('reviewrequest.md') do |f|
        f << initial_text
        f.flush

        editor = repo.config['core.editor'] || ENV['EDITOR'] || 'vi'
        flags = case editor
        when 'mate', 'emacs', 'subl'
          '-w'
        when 'mvim'
          '-f'
        else
          ''
        end
        pid = fork { exec([editor, flags, f.path].join(' ')) }
        Process.waitpid(pid)
        File.read(f.path)
      end
    end
  end
end
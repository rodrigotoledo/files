require "minitest/autorun"
require "files"
require "rbconfig"

class FilesTest < Minitest::Test
  include Files
  def windows?
    RbConfig::CONFIG["host_os"] =~ %r!(msdos|mswin|djgpp|mingw|[Ww]indows)!
  end

  def setup
    @here = File.expand_path("data", File.dirname(__FILE__))
  end

  def test_files_object
    files = self.create # creates a temporary directory inside Dir.tmpdir
    assert files.root, "Files root should exist"

    files.file "hello.txt" # creates file "hello.txt" containing "contents of hello.txt"
    files.dir "web" do      # creates directory "web"
      file "snippet.html",  # creates file "web/snippet.html", with content
           "<h1>File under F for fantastic!</h1>"
      dir "img" do          # creates directory "web/img"
        file File.new("#{@here}/cheez_doing_it_wrong.jpg") # copy of cheez_doing_it_wrong.jpg
        file "other.jpg",   # a different named file
             File.new("#{@here}/cheez_doing_it_wrong.jpg") # with same content
      end
    end

    dir = files.root
    assert_match(/^files_test/, dir.split('/').last, "Directory should end with files_test")
    assert_match(/^#{Regexp.escape(Dir.tmpdir)}/, dir, "Directory should be inside tmpdir")
    assert_equal "contents of hello.txt", File.read("#{dir}/hello.txt")
    assert_equal "<h1>File under F for fantastic!</h1>", File.read("#{dir}/web/snippet.html")
    
    # Ensure paths are correct when referencing `cheez_doing_it_wrong.jpg`
    assert_equal File.read("#{@here}/cheez_doing_it_wrong.jpg"),
                 File.read("#{dir}/web/img/cheez_doing_it_wrong.jpg")
    assert_equal File.read("#{@here}/cheez_doing_it_wrong.jpg"),
                 File.read("#{dir}/web/img/other.jpg")

    files.remove
    refute File.exist?(dir), "Root directory and all contents should be removed"

    assert_raises(Errno::ENOENT) { files.file "uhoh.txt" }
  end

  def test_files_method
    dir = Files do
      file "hello.txt"
      dir("web") { file "hello.html" }
    end
    assert dir, "Directory should be created"
    assert_equal "contents of hello.txt", File.read("#{dir}/hello.txt")
    assert_equal "contents of hello.html", File.read("#{dir}/web/hello.html")
    assert_match(/^files_test/, dir.split('/').last, "Directory name should match files_test")
  end

  def test_nested_files_structure
    dir = Files do
      dir "foo" do
        file "foo.txt"
      end
      dir "bar" do
        file "bar.txt"
        dir "baz" do
          file "baz.txt"
        end
        dir "baf" do
          file "baf.txt"
        end
      end
    end
    assert_equal "contents of foo.txt", File.read("#{dir}/foo/foo.txt")
    assert_equal "contents of bar.txt", File.read("#{dir}/bar/bar.txt")
    assert_equal "contents of baz.txt", File.read("#{dir}/bar/baz/baz.txt")
    assert_equal "contents of baf.txt", File.read("#{dir}/bar/baf/baf.txt")
  end

  def test_data_directory_copy
    src = File.expand_path("#{@here}")
    files = File.create do
      dir "foo", src: src do
        # Adjust path to match where `cheez_doing_it_wrong.jpg` would be copied in `foo`
        assert File.exist?(File.join(Dir.pwd, 'foo/cheez_doing_it_wrong.jpg')),
               "Data directory should contain cheez_doing_it_wrong.jpg"
      end
    end
  end

  def test_directory_existence
    dir = Files()
    assert File.exist?(dir) && File.directory?(dir), "Directory should exist and be a directory"

    dir = Files do
      dir "a"
    end
    assert File.exist?("#{dir}/a") && File.directory?("#{dir}/a"), "Nested directory 'a' should exist"
  end

  def test_returned_paths
    stuff = nil
    hello = nil
    files_dir = Files do
      stuff = dir "stuff" do
        hello = file "hello.txt"
      end
    end

    assert_equal "#{files_dir}/stuff", stuff, "Path for 'stuff' directory should match"
    assert_equal "#{files_dir}/stuff/hello.txt", hello, "Path for 'hello.txt' should match"
  end

  def test_directory_inside_block
    dir_inside_do_block = nil
    # dir = Files do
      dir_inside_do_block = Dir.pwd
      dir "xyzzy" do
        assert_equal "xyzzy", File.basename(Dir.pwd), "Should set the current directory inside the dir block"
      end
    # end
    assert_equal File.basename(dir), File.basename(dir_inside_do_block),
                 "Should set the current directory inside the Files block"
  end
end


## Testing the Mixin interface (which is the alternate public API)
class FilesMixinTest < Minitest::Test
  include Files

  def setup
    @files = nil
  end

  def test_files_mixin
    assert_nil @files, "Initially, @files should be nil"

    file "foo.txt"
    assert @files&.root, "Calling 'file' creates the @files instance variable with a root"
    assert_equal @files.object_id, files.object_id, "The 'files' method should return the @files instance variable"

    assert File.exist?("#{@files.root}/foo.txt"), "File 'foo.txt' should exist in the root directory"
    assert_equal "contents of foo.txt", File.read("#{@files.root}/foo.txt"), "Contents of 'foo.txt' should be correct"

    files = self.create do
      dir "bar" do
        file "bar.txt"
        dir "sub" do
          file "sub.txt"
        end
      end
    end

    assert_equal "contents of bar.txt", File.read("#{files.root}/bar/bar.txt"),
                 "Contents of 'bar.txt' should be correct within the directory"
    assert_equal "contents of sub.txt", File.read("#{files.root}/bar/sub/sub.txt"),
                 "Contents of 'sub.txt' should be correct within nested directory"

    assert_equal "contents of bar.txt", File.read("#{@files.root}/bar/bar.txt"),
                 "File 'bar.txt' should exist under the root directory"

    subdir = dir "baz"
    assert File.exist?("#{@files.root}/baz"), "The 'baz' directory should be created"
    assert_equal "#{@files.root}/baz", subdir, "The 'dir' method should return the created directory path"
    assert File.directory?("#{@files.root}/baz"), "'baz' should be a directory"

    # Verify preservation of instance variables in directory blocks
    @content = "breakfast"
    dir "stuff" do
      assert_nil @content, "Instance variables should not be preserved within directory blocks"
    end
  end
end

#TODO: fix create and Files methods
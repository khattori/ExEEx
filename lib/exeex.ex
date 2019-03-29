defmodule ExEEx do
  @moduledoc """
  Documentation for ExEEx.
  """

  @doc """
  Render template file.

  ## Examples

      iex> ExEEx.render("test/templates/hello.txt", val: "world")
      "Hello, world!\\n"

      iex> ExEEx.render("test/templates/main.txt")
      "This is header\\n---\\nThis is body\\n---\\nThis is footer\\n\\n"
  """
  def render(filename, params \\ [])
  def render(%ExEEx.Template{code: code}, params) when is_list(params) do
    if not Keyword.keyword?(params) do
      raise ExEEx.TemplateError, message: "expected keywords as template parameters"
    end
    {result, _binding} = Code.eval_quoted(code, params)
    result
  end
  def render(filename, params) when is_binary(filename) and is_list(params) do
    compile(filename)
    |> render(params)
  end

  @doc """
  Render template string.

  ## Examples

      iex> ExEEx.render_string("Hello, world!")
      "Hello, world!"

      iex> ExEEx.render_string("<%= include \\"test/templates/hello.txt\\" %>OK", val: "world")
      "Hello, world!
      OK"

      iex> ExEEx.render_string("<%= block \\"header\\" do %>This is default header<% end %>")
      "This is default header"
  """
  def render_string(template, params \\ []) when is_list(params) do
    compile_string(template)
    |> render(params)
  end

  @doc """
  Compile template file.

  ## Examples

      iex> ExEEx.compile("test/templates/hello.txt").name
      "hello.txt"
  """
  def compile(filename, opts \\ []) when is_binary(filename) do
    adapter = Application.get_env(:exeex, :adapter, ExEEx.Adapter.FileStorage)
    file_path = adapter.expand_path(filename)
    adapter.read(file_path)
    |> compile_string(Keyword.put(opts, :file, file_path))
  end

  @doc """
  Compile template file.

  ## Examples

      iex> ExEEx.compile_string("Hello, world!").name
      :nofile
  """
  def compile_string(source, opts \\ []) when is_binary(source) do
    adapter = Application.get_env(:exeex, :adapter, ExEEx.Adapter.FileStorage)
    file = Keyword.get(opts, :file)
    {dir, name} =
      if file do
        # 絶対パスに変換
        file_path = adapter.expand_path(file)
        #
        # ファイルパスが渡されている場合、ディレクトリとベース名に分割
        #
        {Path.dirname(file_path), Path.basename(file_path)}
      else
        #
        # インメモリの場合、現在のディレクトリ
        #
        {adapter.expand_path("."), :nofile}
      end
    Process.put(:includes, [{dir, name}])
    Process.put(:blocks, [%{}])
    Process.put(:defblocks, [[]])
    code =
      EEx.compile_string(source, Keyword.put(opts, :file, to_string(name)))
      |> ExEEx.Engine.expand_macro()
    Process.delete(:defblocks)
    Process.delete(:blocks)
    Process.delete(:includes)
    %ExEEx.Template{
      code: code,
      path: dir,
      name: name
    }
  end
end

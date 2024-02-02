defmodule Http.Help do
  def get_res(question) do
    case question do
      "get_info" ->
        "此接口用于获取目前在bot服的连接信息, 返回参数为save_info接口中上传的连接信息"

      "save_info" ->
        "此接口用于向bot服上传连接信息, 包含"

      _ ->
        "不包含#{question}的帮助信息"
    end
  end
end

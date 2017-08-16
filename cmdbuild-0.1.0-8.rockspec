package = "cmdbuild"
version = "0.1.0-8"
source = {
  url = "https://bitbucket.org/enlab/cmdbuild_soap_api",
  tag = "0.1.0-8"
}
description = {
  summary = "CMDBuild SOAP API Wrapper",
  detailed = [[
    cmdbuild is/will be a unified wrapper around a few common lua http client libraries
    ]],
    homepage = "https://bitbucket.org/enlab/cmdbuild_soap_api",
    license = "MIT"
}
dependencies = {
  "luasocket ~> 3.0rc1-2",
  "luaxml ~> 101012-2",
  "lua-cjson ~> 2.1.0-1"
}
build = {
  type = "builtin",
  modules = {
    ['cmdbuild'] = 'src/cmdbuild.lua',
    ['cmdbuild.attachment'] = 'src/cmdbuild/attachment.lua',
    ['cmdbuild.card'] = 'src/cmdbuild/card.lua',
    ['cmdbuild.lookup'] = 'src/cmdbuild/lookup.lua',
    ['cmdbuild.workflow'] = 'src/cmdbuild/workflow.lua',
    ['base64'] = 'src/base64.lua',
    ['Log'] = 'src/Log.lua',
    ['Utils'] = 'src/Utils.lua'
  }
}

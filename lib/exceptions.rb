# -*- encoding: utf-8 -*-
# Copyright (c) 2014 Pivotal Software, Inc. All Rights Reserved.
module Exceptions
  class ArgumentError < StandardError; end
  class BackendError < StandardError; end
  class NotFound < StandardError; end
  class NotImplemented < StandardError; end
  class NotSupported < StandardError; end
end

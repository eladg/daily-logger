root = ::File.dirname(__FILE__)
require ::File.join( root, 'app' )
use ExceptionHandling
run SlackLogger.new

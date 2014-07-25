require 'aws-sdk'

class Store
    def contains?(name)
        raise NotImplementedError
    end
    def read(name)
        raise NotImplementedError
    end
    def write(name, text)
        raise NotImplementedError
    end
    def list(stub)
        raise NotImplementedError
    end
    def delete(name)
        raise NotImplementedError
    end
end

class S3Store < Store
    def initialize(id, secret, bucket)
        @sess = AWS::S3.new(:access_key_id => id,
                            :secret_access_key => secret)
        @bucket = @sess.buckets[bucket]
    end

    def contains?(name)
        return @bucket.objects.with_prefix(name).count > 0
    end

    def read(name)
        return @bucket.objects[name].read
    end

    def write(name, text)
        @bucket.objects[name].write(text)
    end

    def list(stub)
        ret = []
        @bucket.objects.with_prefix(stub).each {|o| ret.push(o.key)}
        return ret
    end

    def delete(name)
        @bucket.objects[name].delete
    end
end

class DiskStore < Store
    def initialize(rootdir)
        @root = rootdir
        if not File.directory?(@root)
            raise StandardError.new('Not an appropriate directory')
        end
    end

    def contains?(name)
        return File.file?(File.join(@root, name))
    end

    def read(name)
        return File.open(File.join(@root, name)).read
    end

    def write(name, text)
        f = File.open(File.join(@root, name), 'w')
        f.write(text)
        f.close
    end

    def list(stub)
        return Dir.entries(File.join(@root, stub)).select { |f|
            File.file?(File.join(@root, stub, f))
        }
    end

    def delete(name)
        File.delete(name)
    end
end


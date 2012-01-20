require 'fog/compute/models/server'

module Fog
  module Compute
    class IBM

      class Server < Fog::Compute::Server

        STATES = [
          "New",            # => 0
          "Provsioning",    # => 1
          "Failed",         # => 2
          "Removed",        # => 3
          "Rejected",       # => 4
          "Active",         # => 5
          "Unknown",        # => 6
          "Deprovisioning", # => 7
          "Restarting",     # => 8
          "Starting",       # => 9
          "Stopping",       # => 10
          "Stopped",        # => 11
          "Deprovisioning pending", # => 12
          "Restart pending",# => 13
          "Attaching",      # => 14
          "Detaching"       # => 15
        ]

        identity :id

        attribute :disk_size, :aliases => 'diskSize'
        attribute :expires_at, :aliases => 'expirationTime'
        attribute :image_id, :aliases => 'imageId'
        attribute :instance_type, :aliases => 'instanceType'
        attribute :ip
        attribute :key_name, :aliases => 'keyName'
        attribute :launched_at, :aliases => 'launchTime'
        attribute :location_id, :aliases => 'location'
        attribute :name
        attribute :owner
        attribute :primary_ip, :aliases => 'primaryIP'
        attribute :product_codes, :aliases => 'productCodes'
        attribute :request_id, :aliases => 'requestId'
        attribute :request_name, :aliases => 'requestName'
        attribute :root_only, :aliases => 'root-only'
        attribute :secondary_ips, :aliases => 'secondaryIP'
        attribute :software
        attribute :state, :aliases => 'status'
        attribute :volume_ids, :aliases => 'volumes'

        def initialize(attributes={})
          self.image_id ||= '20025202'
          self.location_id ||= '82'
          super
        end

        def save
          requires :name, :image_id, :instance_type, :location_id
          connection.create_instance(name, image_id, instance_type, location_id, key_name).body['instances'].each do |iattrs|
            if iattrs['name'] == name
              merge_attributes(iattrs)
              return true
            end
          end
          false
        end

        def state
          STATES[attributes[:state].to_i]
        end

        def ready?
          state == "Active"
        end

        def reboot
          requires :id
          connection.modify_instance(id, 'state' => 'restart')
        end

        def destroy
          requires :id
          data = connection.delete_instance(id)
          data.body['success']
        end

        def rename(name)
          requires :id
          if connection.modify_instance(id, {'name' => name}).body["success"]
            attributes[:name] = name
          else
            return false
          end
          true
        end

        def allocate_ip(wait_for_ready=true)
          requires :location_id
          new_ip = connection.addresses.new(:location => location_id)
          new_ip.save
          new_ip.wait_for { ready? } if wait_for_ready
          secondary_ip << new_ip
          new_ip
        end

        def addresses
          addys = secondary_ip.map {|ip| Fog::Compute[:ibm].addresses.new(ip) }
          # Set an ID, in case someone tries to save
          addys << connection.addresses.new(attributes[:primary_ip].merge(
            :id => "0",
            :location => location_id,
            :state => 3
          ))
          addys
        end

        def attach(volume_id)
          requires :id
          data = connection.modify_instance(id, {'type' => 'attach', 'storageId' => volume_id})
          data.body
        end

        def detach(volume_id)
          requires :id
          data = connection.modify_instance(id, {'type' => 'detach', 'storageId' => volume_id})
          data.body
        end

        def expires_at
          Time.at(attributes[:expires_at].to_f / 1000)
        end

        # Sets expiration time - Pass an instance of Time.
        def expire_at(time)
          expiry_time = (time.tv_sec * 1000).to_i
          success = connection.set_instance_expiration(id, expiry_time).body["expirationTime"] == expiry_time
          if success
            attributes[:expires_at] = expiry_time
          end
          success
        end

        # Expires the instance immediately
        def expire!
          expire_at(Time.now)
        end

        def image
          requires :image_id
          connection.images.get(image_id)
        end

        def location
          requires :location_id
          connection.locations.get(location_id)
        end

        def public_hostname
          attributes[:primary_ip]["hostname"]
        end

        def public_ip_address
          attributes[:primary_ip]["ip"]
        end

        # Creates an image from the current instance
        # if name isn't passed then we'll take the current name and timestamp it
        def to_image(opts={})
         options = {
           :name => name + " as of " + Time.now.strftime("%Y-%m-%d %H:%M"),
           :description => ""
         }.merge(opts)
         connection.create_image(id, options[:name], options[:description]).body
        end
        alias :create_image :to_image
      end

    end
  end

end

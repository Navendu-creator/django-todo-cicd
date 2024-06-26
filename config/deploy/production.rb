set :stage, :production
server 'ec2-54-145-179-195.compute-1.amazonaws.com', user: 'passenger', roles: %w{app}
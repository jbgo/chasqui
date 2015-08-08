# Chasqui

Chasqui is a simple, lightweight, persistent implementation of the publish-subscribe (pub/sub)
messaging pattern for service oriented architectures.

Chasqui delivers messages to subscribers in a Resque-compatible format. If you are already
using Resque and/or Sidekiq, Chasqui will make a wonderful companion to your architecture.

## Why do you need Chasqui?

* To reduce coupling between applications
* To process, monitor, and retry messages idependent of request cycles

## Design

Chasqui is designed with reliability in mind.
Failure is expected and planned for in the design.

Chasqui uses Redis to create persistent queues. Chasqui does not use the Redis Pub/Sub feature
because it cannot ensure delivery of messages, especially when subscribers are not running.

Chasqui consists of two components, a client and a server.
The client provides a simple interface for publishing messages. The client places messages
on a persistent queue, called an inbox, where they wait for further processing.
The server reads messages from the inbox and places them on the queues of each subscriber.
The server will create queues for subscribers if the queues do not exist.

The advantage of this design is that messages are not lost when the chasqui server or the
chasqui subscribers are not running.

## Is Chasqui the best choice for you?

Chasqui is perfect for you if your current architecture meets all of the following criteria
listed below.

1. You have a service oriented architecture of some kind.
2. You primarily use resque and/or sidekiq to process jobs already.
3. You want a simple Pub/Sub solution with minimal setup and maintenance.
4. Your organization or traffic volume is not high enough to warrant a more complex solution.

If any of the above are not true for you, you may want to consider other available solutions.
This website maintains a list of alternatives for you to consider: http://queues.io/

If Chasqui is not right for you, then please use another solution. I designed Chasqui to
solve a specific problem for a particular scale and company size.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'chasqui'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chasqui

## Publishing events

Publishing events is simple.

```rb
Chasqui.publish 'user.sign-up', user_id
```

To prevent conflicts with other applications, you can choose a unique namespace for your events.

```rb
# config/initializers/chasqui.rb
Chasqui.configure do |config|
  config.namespace = 'com.example.myapp'
end
```

Now when you call `Chasqui.publish 'event.name', data, ...`, Chasqui will publish the event
`com.example.myapp.user.sign-up`.

## Subscribing to events (COMING SOON)

```rb
# file: otherapp/app/subscribers/user_events.rb
Chasqui.subscribe queue: 'unique_queue_name_for_app', namespace: 'com.example.myapp' do

  on 'user.sign-up' do |user_id|
    user = User.find user_id
    UserMailer.signup(user).deliver
  end

  on 'user.cancel' do |user_id, reason|
    user = User.find user_id
    AdminMailer.user_cancelled(user, reason).deliver
    user.archive!
  end

end
```

## Configure Chasqui

```rb
Chasqui.configure do |config|
  config.namespace = 'com.example.transcoder'
  config.redis = ENV.fetch('REDIS_URL')
  config.workers = :sidekiq # or :resque
  ...
end
```

## Contributing

1. Fork it (https://github.com/[my-github-username]/chasqui/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request


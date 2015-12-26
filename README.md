[![Build Status](https://travis-ci.org/jbgo/chasqui.svg?branch=master)](https://travis-ci.org/jbgo/chasqui)
[![Code Climate](https://codeclimate.com/github/jbgo/chasqui/badges/gpa.svg)](https://codeclimate.com/github/jbgo/chasqui)

# Chasqui

Chasqui adds persistent
[publish-subscribe](https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern)
(pub-sub) messaging capabilities to Sidekiq and Resque workers.

## Installation

Add this line to your application's Gemfile

    gem 'chasqui'

then execute

    $ bundle

or install it yourself as

    $ gem install chasqui

## Dependencies

Chasqui uses [Redis](http://redis.io/) to store events and manage
subscriptions. You can install Redis with your favorite package manager, such
as homebrew, yum, or apt, or if you prefer, you can run `vagrant up` to run
Redis in a virtual machine. If you already have Resque or Sidekiq working, then
you already have everything you need to get started with Chasqui.

## Quick Start

### Start the broker

    chasqui -r redis://localhost:6379/0

The broker is a ruby daemon that listens for events (messages) published to
channels (topics) and forwards those events to registered subscribers.  In
order to work, your broker must use the same Redis database as your
Sidekiq/Resque workers. For a list of available broker options, see `chasqui
--help`.

### Publish events

    Chasqui.publish 'order.purchased', user, order

Publish an event to the `order.purchased` channel and include information
about the user and order that triggered the event. Any arguments after the
channel name must be JSON-serializable.

### Define workers to handle events

With Sidekiq

    class OrderPublishWorker
      include Sidekiq::Worker
      sidekiq_options queue: 'pubsub' # you can use any options sidekiq supports

      def perform(event, user, order_details)
        # custom logic to handle the event
      end
    end

With Resque

    class OrderPublishWorker
      @queue = 'pubsub' # choice of queue name is up to you

      def self.perform(event, user, order_details)
        # custom logic to handle the event
      end
    end

The `OrderPublishWorker` is a normal Sidekiq (or Resque) worker. The first
argument to the perform method is a [Chasqui::Event](#) object, and the
remaining arguments are the same arguments you passed to `Chasqui.publish`.

### Subscribe to events

    Chasqui.subscribe do
      on 'order.purchased', PurchasedOrderWorker
      # ...more subscriptions
    end

The above code tells Chasqui to place events published to the `order.purchased`
channel on `PurchaseOrderWorker`'s queue.

You can also use a callable object instead of a worker class to handle events.

    Chasqui.subscribe queue: 'app_id:pubsub' do
      on 'order.purchased', ->(event, user, order) {
        logger.info event.to_json
      }
    end

### Running Subscribers

With Sidekiq

    bundle exec sidekiq -q app_id:pubsub

With Resque

    QUEUES=app_id:pubsub bundle exec rake resque:work

Subscribers are normal Sidekiq or Resque workers, and can take advantage of all
available features and plugins.  Please refer to the documentation for those
libraries for detailed instructions.

* [Sidekiq documentation](https://github.com/mperham/sidekiq)
* [Resque documentation](https://github.com/resque/resque)

### Configuration

    Chasqui.configure do |c|
      c.redis = 'redis://my-redis.example.com:6379'
      ...
    end

For a full list of configuration options, see the
[Chasqui::Config documentation](http://www.rubydoc.info/gems/chasqui/Chasqui/Config).

## Unsubscribing

    Chasqui.unsubscribe 'order.purchased', 'app_id:pubsub'

If you no longer wish to handle events for a channel, you should unsubscribe
the worker so that the Chasqui broker stops placing jobs on that worker's
queue.

## Why Chasqui?

* Persistent - events don't get lost when the broker restarts or your workers
  are not running.
* Integrates with the proven Sidekiq and Resque background worker libraries.
* Reduces service coupling - publishers have no knowledge of subscribers and
  subscribers have no knowledge of publishers.

## Limitations

Chasqui requires that the publisher, broker, and all subscribers must connect
to the same Redis database. If your applications use separate Redis databases,
they will not be able to communicate with each other using Chasqui.

## Contributing

* For feature requests, please [open an issue](https://github.com/jbgo/chasqui/issues/new)
  to discuss the proposed feature.
* For bug fixes, you are welcome to create a pull request without first opening
  an issue.
* Except for documentation changes, tests are required with all pull requests.
* Please be polite and respectful when discussing the project with maintainers
  and your fellow contributors.

## Code of Conduct

If you are unsure whether or not your communication is appropriate for Chasqui
please consult the [Chasqui Code of Conduct](code-of-conduct.md).  If you
suspect harassment or abuse, please report it to the email address listed in
the Code of Conduct.

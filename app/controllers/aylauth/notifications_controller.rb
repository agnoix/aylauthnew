module Aylauth
  class NotificationsController < ::ApplicationController

    def logout
      if request.raw_post != ""
        data = JSON.parse(request.raw_post)
        if data["Type"] == "SubscriptionConfirmation"
          confirm_subscription data
        elsif data["Type"] == "Notification" #SNS
          message = JSON.parse(data["Message"])
          invalidate_token(message['token'])
          head :ok and return
        end
      end
      head :bad_request
    end

    def refresh_user
      if request.raw_post != ""
        data = JSON.parse(request.raw_post)
        if data["Type"] == "SubscriptionConfirmation"
          confirm_subscription data
        elsif data["Type"] == "Notification"
          message = JSON.parse(data["Message"])
          invalidate_token(message['token']) #Force look up in User Service
          head :ok and return
        end
      end
      head :bad_request
    end

    def refresh_contact
      if request.raw_post != ""
        data = JSON.parse(request.raw_post)
        if data["Type"] == "SubscriptionConfirmation"
          confirm_subscription data
        elsif data["Type"] == "Notification"
          message = JSON.parse(data["Message"])
          contact_id = message['contact_id']
          action = message['action']
          Aylauth::Cache.expire("contact_id", contact_id)
          if action == 'delete' && defined?(TriggerApp)
            trigger_apps = TriggerApp.where(contact_id: contact_id)
            trigger_apps.destroy_all
          end
          if action == 'delete' && defined?(NotificationApp) && defined?(NotificationApp) && defined?(NotificationAppParameter)
            notification_apps_parameters = NotificationAppParameter.where(param_name: 'contact_id', param_value: contact_id)
            notification_apps = notification_apps_parameters.flat_map{|parameter| NotificationApp.where(id: parameter.notification_app_id)}
            notification_apps.each {|notificationApp| notificationApp.destroy}
          end
          head :ok and return
        end
      end
      head :bad_request
    end

    private

    def confirm_subscription data
      client = AWS::SNS::Client.new(:region => AWS_CONFIG["region"], :endpoint => AWS_CONFIG["endpoint"])
      client.confirm_subscription(:topic_arn => data["TopicArn"], :token => data["Token"])
      head :ok
    end
  end
end

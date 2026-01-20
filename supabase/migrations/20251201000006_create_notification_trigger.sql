-- Create function to handle notification sending
CREATE OR REPLACE FUNCTION handle_new_interpreter_request()
RETURNS TRIGGER AS $$
BEGIN
  -- This function will be called when a new interpreter request is inserted
  -- The actual notification logic is handled in the application layer
  -- This trigger ensures the notification process is triggered automatically
  
  -- You can add additional logic here if needed
  -- For example, logging the event or updating other tables
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on interpreter_requests table
CREATE TRIGGER trigger_new_interpreter_request
  AFTER INSERT ON public.interpreter_requests
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_interpreter_request();

-- Create function to log notification events
CREATE OR REPLACE FUNCTION log_notification_event(
  request_id UUID,
  interpreter_count INTEGER,
  notification_sent BOOLEAN
) RETURNS VOID AS $$
BEGIN
  -- Log the notification event for debugging
  INSERT INTO notifications (
    user_id,
    title,
    body,
    data,
    type
  ) VALUES (
    NEW.requester_id,
    'Request Created',
    'Your interpreter request has been created',
    jsonb_build_object(
      'request_id', request_id,
      'interpreter_count', interpreter_count,
      'notification_sent', notification_sent,
      'from_language', NEW.from_language,
      'to_language', NEW.to_language,
      'urgency', NEW.urgency
    ),
    'request_created'
  );
END;
$$ LANGUAGE plpgsql; 
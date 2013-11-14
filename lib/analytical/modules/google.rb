module Analytical
  module Modules
    class Google
      include Analytical::Modules::Base

      def initialize(options={})
        super
        @tracking_command_location = :head_append
      end

      def init_javascript(location)
        init_location(location) do
          js = <<-HTML
          <!-- Analytical Init: Google -->
          <script type="text/javascript">
            if (!window['disableAnalytical']) {
              var _gaq = _gaq || [];
              _gaq.push(['_setAccount', '#{options[:key]}']);
              _gaq.push(['_setDomainName', '#{options[:domain]}']);
              #{"_gaq.push(['_setAllowLinker', true]);" if options[:allow_linker]}
              #{"_gaq.push(['_trackPageview']);" unless options[:manually_track_pageviews]}
              (function() {
                var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
                ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
                var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
              })();
            }
          </script>
          HTML
          js
        end
      end

      def enabled?
        !(options[:key].blank?)
      end

      def track(*args)
        "if (!window['disableAnalytical']) { _gaq.push(['_trackPageview'#{args.empty? ? ']' : ', "' + args.first + '"]'}); }"
      end
      
      def event(name, *args)
        data = args.first
        data = {} unless data.is_a?(Hash)
        category = data[:category] || "Event"
        action = name
        label, value, noninteraction = data[:label], data[:value], data[:noninteraction]
        args = ['_trackEvent', category, action, label, value, noninteraction]
        args.pop while args[-1].nil?
        "if (!window['disableAnalytical']) { _gaq.push(#{args.to_json}); }"
      end

      def event_javascript
        js = <<-HTML
        if (!window['disableAnalytical']) {
          if (data.category == null) {
            data.category = "Event";
          }
          _gaq.push(['_trackEvent', data.category, name, data.label, data.value, data.noninteraction]);
        }
        HTML
      end
      
      def custom_event(category, action, opt_label=nil, opt_value=nil)
        args = [category, action, opt_label, opt_value].compact
        "if (!window['disableAnalytical']) { _gaq.push(" + [ "_trackEvent", *args].to_json + "); }"
      end


      # http://code.google.com/apis/analytics/docs/tracking/gaTrackingCustomVariables.html
      #
      #_setCustomVar(index, name, value, opt_scope)
      #
      # index — The slot for the custom variable. Required. This is a number whose value can range from 1 - 5, inclusive.
      #
      # name —  The name for the custom variable. Required. This is a string that identifies the custom variable and appears in the top-level Custom Variables report of the Analytics reports.
      #
      # value — The value for the custom variable. Required. This is a string that is paired with a name.
      #
      # opt_scope — The scope for the custom variable. Optional. As described above, the scope defines the level of user engagement with your site.
      # It is a number whose possible values are 1 (visitor-level), 2 (session-level), or 3 (page-level).
      # When left undefined, the custom variable scope defaults to page-level interaction.
      def set(data)
        if data.is_a?(Hash) && data.keys.any?
          index = data[:index].to_i
          name  = data[:name ]
          value = data[:value]
          scope = case data[:scope].to_s
          when '1', '2', '3' then data[:scope].to_i
          when 'visitor' then 1
          when 'session' then 2
          when 'page' then 3
          else nil
          end
          if (1..5).to_a.include?(index) && !name.nil? && !value.nil?
            data = "#{index}, '#{name}', '#{value}'"
            data += (1..3).to_a.include?(scope) ? ", #{scope}" : ""
            return "if (!window['disableAnalytical']) { _gaq.push(['_setCustomVar', #{ data }]); }"
          end
        end
      end

      def set_javascript
        js = <<-HTML
        var index = parseInt(data.index);
        if (!window['disableAnalytical'] && index >= 1 && index <= 5 && data.name && data.value) {
          var scope = null;
          switch (data.scope) {
            case '1':
            case '2':
            case '3':
              scope = parseInt(data.scope); break;
            case 'visitor': scope = 1; break;
            case 'session': scope = 2; break;
            case 'page': scope = 3; break;
            default: scope = data.scope;
          }
          _gaq.push(['_setCustomVar', index, data.name, data.value, scope]);
        }
        HTML
      end

      # http://code.google.com/apis/analytics/docs/gaJS/gaJSApiEcommerce.html#_gat.GA_Tracker_._addTrans
      # String orderId      Required. Internal unique order id number for this transaction.
      # String affiliation  Optional. Partner or store affiliation (undefined if absent).
      # String total        Required. Total dollar amount of the transaction.
      # String tax          Optional. Tax amount of the transaction.
      # String shipping     Optional. Shipping charge for the transaction.
      # String city         Optional. City to associate with transaction.
      # String state        Optional. State to associate with transaction.
      # String country      Optional. Country to associate with transaction.
      def add_trans(order_id, affiliation=nil, total=nil, tax=nil, shipping=nil, city=nil, state=nil, country=nil)
        data = []
        data << "'#{order_id}'"
        data << "'#{affiliation}'"
        data << "'#{total}'"
        data << "'#{tax}'"
        data << "'#{shipping}'"
        data << "'#{city}'"
        data << "'#{state}'"
        data << "'#{country}'"

        "if (!window['disableAnalytical']) { _gaq.push(['_addTrans', #{data.join(', ')}]); }"
      end

      # http://code.google.com/apis/analytics/docs/gaJS/gaJSApiEcommerce.html#_gat.GA_Tracker_._addItem
      # String orderId  Optional Order ID of the transaction to associate with item.
      # String sku      Required. Item's SKU code.
      # String name     Required. Product name. Required to see data in the product detail report.
      # String category Optional. Product category.
      # String price    Required. Product price.
      # String quantity Required. Purchase quantity.
      def add_item(order_id, sku, name, category, price, quantity)
        data  = "'#{order_id}', '#{sku}', '#{name}', '#{category}', '#{price}', '#{quantity}'"
        "if (!window['disableAnalytical']) { _gaq.push(['_addItem', #{data}]); }"
      end

      # http://code.google.com/apis/analytics/docs/gaJS/gaJSApiEcommerce.html#_gat.GA_Tracker_._trackTrans
      # Sends both the transaction and item data to the Google Analytics server.
      # This method should be used in conjunction with the add_item and add_trans methods.
      def track_trans
        "if (!window['disableAnalytical']) { _gaq.push(['_trackTrans']); }"
      end

    end
  end
end
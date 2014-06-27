﻿using System;
using CodeSmith.Core.Component;
using Exceptionless.Core.Extensions;
using Exceptionless.Models.Data;
using Newtonsoft.Json.Linq;

namespace Exceptionless.Core.Plugins.EventUpgrader {
    [Priority(2000)]
    public class V2EventUpgrade : IEventUpgraderPlugin {
        public void Upgrade(EventUpgraderContext ctx) {
            if (ctx.Version > new Version(2, 0))
                return;

            bool isNotFound = ctx.Document.GetPropertyStringValue("Code") == "404";
            if (isNotFound)
                ctx.Document.Remove("Id");
            else
                ctx.Document.RenameOrRemoveIfNullOrEmpty("Id", "ReferenceId");

            ctx.Document.RenameOrRemoveIfNullOrEmpty("OccurrenceDate", "Date");
            ctx.Document.Remove("OrganizationId");
            ctx.Document.Remove("ProjectId");
            ctx.Document.Remove("ErrorStackId");
            ctx.Document.Remove("ExceptionlessClientInfo");
            ctx.Document.Remove("IsFixed");
            ctx.Document.Remove("IsHidden");
            ctx.Document.RemoveIfNullOrEmpty("Tags");
            ctx.Document.RenameOrRemoveIfNullOrEmpty("RequestInfo", "req");
            ctx.Document.RenameOrRemoveIfNullOrEmpty("EnvironmentInfo", "env");

            ctx.Document.RenameOrRemoveIfNullOrEmpty("ExtendedData", "Data");
            ctx.Document.RenameAll("ExtendedData", "Data");
            var extendedData = ctx.Document.Property("Data") != null ? ctx.Document.Property("Data").Value as JObject : null;
            if (extendedData != null)
                extendedData.RenameOrRemoveIfNullOrEmpty("TraceLog", "trace");

            string emailAddress = ctx.Document.GetPropertyStringValueAndRemove("UserEmail");
            string userDescription = ctx.Document.GetPropertyStringValueAndRemove("UserDescription");
            if (!String.IsNullOrWhiteSpace(emailAddress) && !String.IsNullOrWhiteSpace(userDescription))
                ctx.Document.Add("desc", new JObject(new UserDescription(emailAddress, userDescription)));

            string identity = ctx.Document.GetPropertyStringValueAndRemove("UserName");
            if (!String.IsNullOrWhiteSpace(identity))
                ctx.Document.Add("user", new JObject(new UserInfo(identity)));

            var error = new JObject();
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "Code");
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "Type");
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "Message");
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "Inner");
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "StackTrace");
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "TargetMethod");
            error.CopyOrRemoveIfNullOrEmpty(ctx.Document, "Modules");

            MoveExtraExceptionProperties(error, extendedData);
            var inner = error["inner"] as JObject;
            while (inner != null) {
                MoveExtraExceptionProperties(inner);
                inner = inner["inner"] as JObject;
            }

            ctx.Document.Add("err", error);
            ctx.Document.Add("Type", new JValue(isNotFound ? "404" : "error"));
            ctx.Document.RemoveIfNullOrEmpty("Data");
        }

        private void MoveExtraExceptionProperties(JObject doc, JObject extendedData = null) {
            if (doc == null)
                return;

            if (extendedData == null)
                extendedData = doc["Data"] as JObject;

            string json = extendedData != null && extendedData["__ExceptionInfo"] != null ? extendedData["__ExceptionInfo"].ToString() : null;
            if (String.IsNullOrEmpty(json))
                return;

            try {
                var extraProperties = JObject.Parse(json);
                foreach (var property in extraProperties.Properties())
                    doc.Add(property.Name, property.Value);
            } catch (Exception) {}

            extendedData.Remove("__ExceptionInfo");
            doc.RemoveIfNullOrEmpty("Data");
        }
    }
}